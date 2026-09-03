from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from models import CompareRequest, CompareResponse, SearchRequest, SearchResponse
from services.catalog import rank_search_results
from services.comparison import compare_cart
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


@app.get("/stores")
async def stores():
    return {
        "stores": list(SCRAPERS),
        "app_store_ids": ["carrefour", "coto", "lagallega"],
    }


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
