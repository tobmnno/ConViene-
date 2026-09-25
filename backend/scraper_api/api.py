import asyncio
from urllib.parse import urlparse

import requests
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from models import CompareRequest, CompareResponse, DiscountsResponse, SearchRequest, SearchResponse
from services.catalog import rank_search_results
from services.comparison import compare_cart
from services.discounts import scrape_discounts
from services.scraper import resolve_stores, scrape_query
from scrapers import SCRAPERS

app = FastAPI(title="Comparador de supermercados", version="1.0.0")

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


def _build_search_response(query: str, stores: list[str], rows, limit: int) -> SearchResponse:
    matches = rank_search_results(query, rows, limit=limit)
    return SearchResponse(
        query=query,
        stores=stores,
        count=len(matches),
        results=matches,
    )


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "stores": list(SCRAPERS),
        "app_store_ids": ["carrefour", "coto", "lagallega"],
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
    q: str = Query(min_length=2),
    limit: int = Query(default=20, ge=1, le=50),
    stores: list[str] | None = Query(default=None),
    engine: str = Query(default="camoufox", pattern="^(camoufox|chromium)$"),
):
    try:
        selected_stores = resolve_stores(stores)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    rows = await scrape_query(q, selected_stores, limit, True, engine)
    return _build_search_response(q, selected_stores, rows, limit)


@app.post("/search", response_model=SearchResponse)
async def search_body(payload: SearchRequest):
    try:
        selected_stores = resolve_stores(payload.stores)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    rows = await scrape_query(payload.query, selected_stores, payload.limit, True, "camoufox")
    return _build_search_response(payload.query, selected_stores, rows, payload.limit)


@app.post("/compare", response_model=CompareResponse)
async def compare(payload: CompareRequest):
    try:
        return await compare_cart(payload.items, payload.stores, payload.limit, True, "camoufox")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
