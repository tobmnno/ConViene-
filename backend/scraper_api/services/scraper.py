from __future__ import annotations

import asyncio
import re
import time
from contextlib import asynccontextmanager

from scrapers import SCRAPERS, STORE_NAMES
from services.monitoring import timed_check

STORE_ALIASES = {
    "carrefour": "carrefour",
    "coto": "coto",
    "lagallega": "la_gallega",
    "la_gallega": "la_gallega",
    "la-gallega": "la_gallega",
    "la gallega": "la_gallega",
}

_SEARCH_CACHE_TTL_SECONDS = 120
_DIRECT_STORE_TIMEOUT_SECONDS = 14
_BROWSER_STORE_TIMEOUT_SECONDS = 38
_search_cache: dict[tuple, tuple[float, list]] = {}
_search_locks: dict[tuple, asyncio.Lock] = {}


def _store_tokens(stores: list[str] | str | None) -> list[str]:
    if not stores:
        return list(STORE_NAMES)
    if isinstance(stores, str):
        stores = [stores]
    tokens: list[str] = []
    for store in stores:
        raw = store.strip()
        if raw.lower() in STORE_ALIASES:
            tokens.append(raw)
        else:
            tokens.extend(item for item in re.split(r"[,\s]+", raw) if item)
    return tokens


def resolve_stores(stores: list[str] | str | None) -> list[str]:
    selected: list[str] = []
    invalid: list[str] = []
    for store in _store_tokens(stores):
        canonical = STORE_ALIASES.get(store.strip().lower())
        if canonical is None or canonical not in SCRAPERS:
            invalid.append(store)
            continue
        if canonical not in selected:
            selected.append(canonical)
    if invalid:
        raise ValueError(f"Supermercados inválidos: {', '.join(invalid)}")
    return selected or list(STORE_NAMES)


@asynccontextmanager
async def open_browser(headless: bool = True, engine: str = "camoufox"):
    if engine == "camoufox":
        from camoufox.async_api import AsyncCamoufox

        async with AsyncCamoufox(headless=headless) as browser:
            yield browser
    else:
        from playwright.async_api import async_playwright

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=headless)
            try:
                yield browser
            finally:
                await browser.close()


async def _search_one_store(context, store_name: str, query: str, limit: int):
    page = await context.new_page()
    try:
        return await asyncio.wait_for(
            SCRAPERS[store_name].search(page, query, limit),
            timeout=_BROWSER_STORE_TIMEOUT_SECONDS,
        )
    finally:
        await page.close()


async def scrape_query_with_browser(browser, query: str, stores: list[str], limit: int):
    context = await browser.new_context(locale="es-AR", timezone_id="America/Argentina/Cordoba")
    try:
        tasks = [asyncio.create_task(_search_one_store(context, store, query, limit)) for store in stores]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        rows = []
        for store_name, result in zip(stores, results):
            if isinstance(result, Exception):
                print(f"{store_name}: ERROR {type(result).__name__}: {result}", flush=True)
                continue
            rows.extend(result)
            print(f"{store_name}: {len(result)} productos", flush=True)
        return rows
    finally:
        await context.close()


async def _search_one_direct_store(store_name: str, query: str, limit: int, context: dict | None):
    direct_search = getattr(SCRAPERS[store_name], "search_direct", None)
    if direct_search is None:
        return None
    finish = timed_check(f"products.{store_name}")
    try:
        rows = await asyncio.wait_for(
            direct_search(query, limit, context=context),
            timeout=_DIRECT_STORE_TIMEOUT_SECONDS,
        )
        finish(success=rows is not None, count=len(rows or []), detail="direct")
        return rows
    except Exception as exc:
        finish(success=False, detail=f"{type(exc).__name__}: {exc}")
        print(f"{store_name}: DIRECT ERROR {type(exc).__name__}: {exc}", flush=True)
        return None


async def scrape_query(
    query: str,
    stores: list[str] | None,
    limit: int,
    headless: bool,
    engine: str = "camoufox",
    context: dict | None = None,
):
    selected_stores = resolve_stores(stores)
    # Coordinates only select a branch before this point. Including them here
    # would create a distinct cache entry for every GPS reading.
    cache_context = {
        key: value
        for key, value in (context or {}).items()
        if key not in {"latitude", "longitude", "location_accuracy_meters"}
    }
    context_key = tuple(sorted(cache_context.items()))
    cache_key = (query.strip().casefold(), tuple(selected_stores), limit, context_key)
    cached = _search_cache.get(cache_key)
    now = time.monotonic()
    if cached and now - cached[0] < _SEARCH_CACHE_TTL_SECONDS:
        return list(cached[1])

    lock = _search_locks.setdefault(cache_key, asyncio.Lock())
    async with lock:
        cached = _search_cache.get(cache_key)
        now = time.monotonic()
        if cached and now - cached[0] < _SEARCH_CACHE_TTL_SECONDS:
            return list(cached[1])
        rows = await _scrape_query_uncached(query, selected_stores, limit, headless, engine, context)
        _search_cache[cache_key] = (time.monotonic(), list(rows))
        if len(_search_cache) > 200:
            expired = [key for key, (created, _) in _search_cache.items() if now - created >= _SEARCH_CACHE_TTL_SECONDS]
            for key in expired:
                _search_cache.pop(key, None)
                _search_locks.pop(key, None)
        return rows


async def _scrape_query_uncached(query, selected_stores, limit, headless, engine, context=None):
    direct_tasks = [
        asyncio.create_task(_search_one_direct_store(store, query, limit, context))
        for store in selected_stores
    ]
    direct_results = await asyncio.gather(*direct_tasks)

    rows = []
    browser_stores = []
    for store_name, result in zip(selected_stores, direct_results):
        if result is None:
            browser_stores.append(store_name)
            continue
        rows.extend(result)
        print(f"{store_name}: {len(result)} productos directos", flush=True)

    if not browser_stores:
        return rows

    async with open_browser(headless=headless, engine=engine) as browser:
        rows.extend(await scrape_query_with_browser(browser, query, browser_stores, limit))
    return rows
