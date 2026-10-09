import asyncio
from contextlib import asynccontextmanager, suppress
import os
from urllib.parse import urlparse

import requests
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from models import CompareRequest, CompareResponse, DiscountsResponse, SearchMatch, SearchRequest, SearchResponse, ShoppingContext, EquivalentsRequest, EquivalentsResponse, ProductReference
from services.catalog import rank_search_results, extract_measurement, valid_gtin
from services.comparison import compare_cart
from services.equivalents import find_equivalents, reference_queries
from services.discounts import clear_discount_cache, scrape_discounts
from services.monitoring import status_snapshot
from services.locations import nearby_coto_branches
from services.refresh import refresh_lagallega_catalog
from services.scraper import resolve_stores, scrape_query
from scrapers import SCRAPERS

async def _refresh_promotions_periodically():
    interval = max(int(os.getenv("CONVIENE_PROMOTIONS_REFRESH_SECONDS", "21600")), 300)
    while True:
        await asyncio.sleep(interval)
        await asyncio.to_thread(refresh_lagallega_catalog, force=True)
        clear_discount_cache()


@asynccontextmanager
async def lifespan(app: FastAPI):
    await asyncio.to_thread(refresh_lagallega_catalog)
    task = asyncio.create_task(_refresh_promotions_periodically())
    try:
        yield
    finally:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


app = FastAPI(title="Comparador de supermercados", version="1.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {"status": "ok", "service": "Comparador de supermercados", "version": "1.0.0"}


def _build_search_response(query: str, stores: list[str], rows, limit: int, context: ShoppingContext | None = None) -> SearchResponse:
    barcode = valid_gtin(query)
    if barcode:
        ranked = [
            SearchMatch(
                product=row,
                score=100,
                normalized_query=barcode,
                normalized_name=row.name.lower(),
                match_type="exact",
            )
            for row in rows
            if valid_gtin(row.ean) == barcode and row.available is not False and row.price is not None
        ]
        ranked.sort(key=lambda match: (match.product.price, match.product.store))
    else:
        ranked = rank_search_results(query, rows, limit=len(rows))
    # Reserve coverage for each source without discarding the relevance order.
    coverage = {store: next((index for index, match in enumerate(ranked) if match.product.store == store), None) for store in stores}
    reserved = {index for index in coverage.values() if index is not None} if limit >= len(stores) else set()
    selected = set(reserved)
    for index in range(len(ranked)):
        if len(selected) >= limit:
            break
        selected.add(index)
    matches = [match for index, match in enumerate(ranked) if index in selected]
    return SearchResponse(
        query=query,
        stores=stores,
        count=len(matches),
        results=matches,
        context=context,
    )


async def _search_catalogs(query, stores, limit, engine, context):
    rows = await scrape_query(query, stores, limit, True, engine, context)
    # Size-specific queries often include retailer-only descriptors. Retry only
    # sources with no eligible result, while still ranking against the user's query.
    if extract_measurement(query)[0] is not None:
        found = {match.product.store for match in rank_search_results(query, rows, limit=len(rows))}
        missing = [store for store in stores if store not in found]
        if missing:
            compact = reference_queries(ProductReference(name=query))[0]
            if compact.casefold() != query.casefold():
                rows.extend(await scrape_query(compact, missing, 50, True, engine, context))
    return rows


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "stores": list(SCRAPERS),
        "app_store_ids": ["carrefour", "coto", "lagallega"],
        "monitoring": status_snapshot(),
    }


@app.get("/operations")
async def operations():
    """Operational status for the scraper sources and promotion refresh job."""
    return status_snapshot()


@app.post("/operations/promotions/refresh")
async def refresh_promotions():
    catalog = await asyncio.to_thread(refresh_lagallega_catalog, force=True)
    clear_discount_cache()
    return {
        "status": "ok" if catalog else "degraded",
        "source": catalog.get("source_url") if catalog else None,
        "checked_at": catalog.get("checked_at") if catalog else None,
        "benefits_received": len(catalog.get("benefits", [])) if catalog else 0,
    }


@app.get("/image")
async def image_proxy(url: str = Query(min_length=8, max_length=1200)):
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(status_code=400, detail="URL de imagen invalida")
    try:
        response = requests.get(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
            },
            timeout=20,
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail="No se pudo cargar la imagen") from exc

    content_type = response.headers.get("content-type", "image/jpeg").split(";")[0]
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=415, detail="La URL no devolvio una imagen")
    return Response(
        content=response.content,
        media_type=content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )


@app.get("/stores")
async def stores():
    return {
        "stores": list(SCRAPERS),
        "app_store_ids": ["carrefour", "coto", "lagallega"],
    }


@app.get("/stores/nearby")
async def nearby_stores(
    latitude: float = Query(ge=-90, le=90),
    longitude: float = Query(ge=-180, le=180),
):
    return {
        "suggestions": nearby_coto_branches(latitude, longitude),
        "source": "configured_branch_directory",
    }


@app.get("/discounts", response_model=DiscountsResponse)
async def discounts(
    date: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
    stores: list[str] | None = Query(default=None),
):
    from datetime import date as date_type

    try:
        selected_stores = resolve_stores(stores)
        selected_date = date_type.fromisoformat(date) if date else None
        return await asyncio.to_thread(scrape_discounts, selected_stores, selected_date)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/search", response_model=SearchResponse)
async def search(
    q: str = Query(min_length=2, max_length=200),
    limit: int = Query(default=20, ge=1, le=50),
    stores: list[str] | None = Query(default=None),
    engine: str = Query(default="camoufox", pattern="^(camoufox|chromium)$"),
    postal_code: str | None = Query(default=None, pattern=r"^\d{4}$"),
    fulfillment: str = Query(default="pickup", pattern="^(pickup|delivery)$"),
    coto_store: str | None = Query(default=None, pattern=r"^\d{1,6}$"),
    carrefour_sales_channel: str | None = Query(default=None, pattern=r"^\d{1,4}$"),
    latitude: float | None = Query(default=None, ge=-90, le=90),
    longitude: float | None = Query(default=None, ge=-180, le=180),
):
    try:
        selected_stores = resolve_stores(stores)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    context = ShoppingContext(postal_code=postal_code, fulfillment=fulfillment, coto_store=coto_store, carrefour_sales_channel=carrefour_sales_channel, latitude=latitude, longitude=longitude)
    rows = await _search_catalogs(q, selected_stores, limit, engine, context.model_dump(exclude_none=True))
    return _build_search_response(q, selected_stores, rows, limit, context)


@app.post("/search", response_model=SearchResponse)
async def search_body(payload: SearchRequest):
    try:
        selected_stores = resolve_stores(payload.stores)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    context = payload.context or ShoppingContext()
    rows = await _search_catalogs(payload.query, selected_stores, payload.limit, "camoufox", context.model_dump(exclude_none=True))
    return _build_search_response(payload.query, selected_stores, rows, payload.limit, context)


@app.post("/compare", response_model=CompareResponse)
async def compare(payload: CompareRequest):
    try:
        return await compare_cart(payload.items, payload.stores, payload.limit, True, "camoufox", payload.context)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/products/equivalents", response_model=EquivalentsResponse)
async def equivalents(payload: EquivalentsRequest):
    try:
        return await find_equivalents(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
