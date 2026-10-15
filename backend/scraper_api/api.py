import asyncio
from contextlib import asynccontextmanager, suppress
import os
import secrets

from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from models import CompareRequest, CompareResponse, DiscountsResponse, SearchMatch, SearchRequest, SearchResponse, ShoppingContext, EquivalentsRequest, EquivalentsResponse, ProductReference
from services.catalog import rank_search_results, extract_measurement, valid_gtin
from services.comparison import compare_cart
from services.equivalents import find_equivalents, reference_queries
from services.discounts import clear_discount_cache, scrape_discounts
from services.monitoring import status_snapshot
from services.locations import nearby_coto_branches
from services.refresh import RefreshInProgress, refresh_lagallega_catalog
from services.scraper import resolve_stores, scrape_query_with_status
from services.images import ImageProxyError, fetch_image
from scrapers import SCRAPERS

_refresh_lock = asyncio.Lock()
_development = os.getenv("CONVIENE_ENV", "production").lower() == "development"
_cors_origins = [origin.strip() for origin in os.getenv("CONVIENE_CORS_ORIGINS", "").split(",") if origin.strip()]

async def _refresh_promotions_periodically():
    interval = max(int(os.getenv("CONVIENE_PROMOTIONS_REFRESH_SECONDS", "21600")), 300)
    while True:
        await asyncio.sleep(interval)
        if not _refresh_lock.locked():
            async with _refresh_lock:
                catalog = await asyncio.to_thread(refresh_lagallega_catalog, force=True)
                if catalog:
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
    allow_origins=_cors_origins,
    allow_origin_regex=r"^http://(?:localhost|127\.0\.0\.1):\d+$" if _development else None,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "X-Admin-Key"],
)


@app.get("/")
async def root():
    return {"status": "ok", "service": "Comparador de supermercados", "version": app.version}


def _build_search_response(query: str, stores: list[str], rows, limit: int, context: ShoppingContext | None = None, source_status: dict[str, str] | None = None) -> SearchResponse:
    barcode = valid_gtin(query)
    barcode_rows = [row for row in rows if valid_gtin(row.ean) == barcode] if barcode else []
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
            if valid_gtin(row.ean) == barcode and row.available is not False and row.price is not None and row.price > 0
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
    found_stores = {match.product.store for match in ranked}
    unavailable_by_store = {}
    for row in barcode_rows:
        if row.store not in found_stores and (row.available is False or row.price is None or row.price <= 0):
            unavailable_by_store.setdefault(row.store, row)
    status = {}
    for store in stores:
        if store in found_stores:
            status[store] = "found"
        elif source_status and source_status.get(store) == "error":
            status[store] = "error"
        elif store in unavailable_by_store:
            status[store] = "unavailable"
        elif any(row.store == store and row.available is False for row in rows) and not any(
            row.store == store and row.available is not False for row in rows
        ):
            status[store] = "unavailable"
        else:
            status[store] = "not_found"
    return SearchResponse(
        query=query,
        stores=stores,
        count=len(matches),
        results=matches,
        context=context,
        store_status=status,
        partial="error" in status.values(),
        unavailable_products=list(unavailable_by_store.values()),
    )


def _validate_search_barcode(query: str) -> None:
    if query.isdigit() and 8 <= len(query) <= 14 and not valid_gtin(query):
        raise HTTPException(status_code=422, detail="Codigo de barras invalido. Revisa los digitos.")


async def _search_catalogs(query, stores, limit, engine, context):
    result = await scrape_query_with_status(query, stores, limit, True, engine, context)
    # Size-specific queries often include retailer-only descriptors. Retry only
    # sources with no eligible result, while still ranking against the user's query.
    if extract_measurement(query)[0] is not None:
        found = {match.product.store for match in rank_search_results(query, result.rows, limit=len(result.rows))}
        missing = [store for store in stores if store not in found]
        if missing:
            compact = reference_queries(ProductReference(name=query))[0]
            if compact.casefold() != query.casefold():
                retry = await scrape_query_with_status(compact, missing, 50, True, engine, context)
                result.rows.extend(retry.rows)
                for store in missing:
                    if store in retry.source_status:
                        result.source_status[store] = retry.source_status[store]
    return result


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "stores": list(SCRAPERS),
        "app_store_ids": ["carrefour", "coto", "lagallega"],
    }


def _require_admin(request: Request, x_admin_key: str | None) -> None:
    configured_key = os.getenv("CONVIENE_ADMIN_KEY", "")
    local = request.client is not None and request.client.host in {"127.0.0.1", "::1"}
    if not _development and (len(configured_key) < 24 or configured_key.strip() != configured_key):
        raise HTTPException(status_code=503, detail="Operacion administrativa no configurada")
    if configured_key:
        if not x_admin_key or not secrets.compare_digest(x_admin_key, configured_key):
            raise HTTPException(status_code=403, detail="Operacion no autorizada")
    elif not (_development and local):
        raise HTTPException(status_code=503, detail="Operacion administrativa no configurada")


@app.get("/operations")
async def operations(request: Request, x_admin_key: str | None = Header(default=None)):
    """Operational status for the scraper sources and promotion refresh job."""
    _require_admin(request, x_admin_key)
    return status_snapshot()


@app.post("/operations/promotions/refresh")
async def refresh_promotions(request: Request, x_admin_key: str | None = Header(default=None)):
    _require_admin(request, x_admin_key)
    if _refresh_lock.locked():
        raise HTTPException(status_code=409, detail="Actualizacion en curso")
    async with _refresh_lock:
        try:
            catalog = await asyncio.to_thread(refresh_lagallega_catalog, force=True, raise_if_locked=True)
        except RefreshInProgress as exc:
            raise HTTPException(status_code=409, detail="Actualizacion en curso") from exc
        if catalog:
            clear_discount_cache()
    return {
        "status": "ok" if catalog else "degraded",
        "source": catalog.get("source_url") if catalog else None,
        "checked_at": catalog.get("checked_at") if catalog else None,
        "benefits_received": len(catalog.get("benefits", [])) if catalog else 0,
    }


@app.get("/image")
async def image_proxy(url: str = Query(min_length=8, max_length=1200)):
    try:
        content, content_type = await asyncio.to_thread(fetch_image, url)
    except ImageProxyError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    return Response(
        content=content,
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
    _validate_search_barcode(q)
    try:
        selected_stores = resolve_stores(stores)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    context = ShoppingContext(postal_code=postal_code, fulfillment=fulfillment, coto_store=coto_store, carrefour_sales_channel=carrefour_sales_channel, latitude=latitude, longitude=longitude)
    result = await _search_catalogs(q, selected_stores, limit, engine, context.model_dump(exclude_none=True))
    return _build_search_response(q, selected_stores, result.rows, limit, context, result.source_status)


@app.post("/search", response_model=SearchResponse)
async def search_body(payload: SearchRequest):
    _validate_search_barcode(payload.query)
    try:
        selected_stores = resolve_stores(payload.stores)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    context = payload.context or ShoppingContext()
    result = await _search_catalogs(payload.query, selected_stores, payload.limit, "camoufox", context.model_dump(exclude_none=True))
    return _build_search_response(payload.query, selected_stores, result.rows, payload.limit, context, result.source_status)


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
