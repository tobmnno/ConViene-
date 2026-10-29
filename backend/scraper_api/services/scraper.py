from __future__ import annotations

import asyncio
from copy import deepcopy
import re
import time
from contextlib import asynccontextmanager
from dataclasses import dataclass

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
_DIRECT_CACHE_TTL_SECONDS = 120
_DIRECT_EMPTY_TTL_SECONDS = 30
_DIRECT_CACHE_MAX_ENTRIES = 512


@dataclass
class SearchQueryResult:
    rows: list
    source_status: dict[str, str]


_search_cache: dict[tuple, tuple[float, SearchQueryResult]] = {}
_search_inflight: dict[tuple, asyncio.Task] = {}
_direct_cache: dict[tuple, tuple[float, int, list]] = {}
_direct_inflight: dict[tuple, asyncio.Task] = {}
_SEARCH_CACHE_MAX_ENTRIES = 200


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
        source_status = {}
        for store_name, result in zip(stores, results):
            if isinstance(result, Exception):
                print(f"{store_name}: ERROR {type(result).__name__}", flush=True)
                source_status[store_name] = "error"
                continue
            rows.extend(result)
            source_status[store_name] = "ok"
            print(f"{store_name}: {len(result)} productos", flush=True)
        return SearchQueryResult(rows, source_status)
    finally:
        await context.close()


async def _search_one_direct_store(store_name: str, query: str, limit: int, context: dict | None):
    cache_context = {
        key: value
        for key, value in (context or {}).items()
        if key not in {"latitude", "longitude", "location_accuracy_meters"}
        and (store_name == "coto" or key != "equivalence_search")
    }
    base_key = (store_name, query.strip().casefold(), tuple(sorted(cache_context.items())))
    now = time.monotonic()
    cached = _direct_cache.get(base_key)
    if cached is not None:
        created, cached_limit, rows = cached
        ttl = _DIRECT_CACHE_TTL_SECONDS if rows else _DIRECT_EMPTY_TTL_SECONDS
        if cached_limit >= limit and now - created < ttl:
            return deepcopy(rows[:limit])

    task_key = (base_key, limit)
    task = _direct_inflight.get(task_key)
    if task is None:
        task = asyncio.create_task(
            _fetch_direct_store(task_key, base_key, store_name, query, limit, context)
        )
        _direct_inflight[task_key] = task
    rows = await asyncio.shield(task)
    return deepcopy(rows) if rows is not None else None


async def _fetch_direct_store(task_key, base_key, store_name, query, limit, context):
    direct_search = getattr(SCRAPERS[store_name], "search_direct", None)
    try:
        if direct_search is None:
            return None
        finish = timed_check(f"products.{store_name}")
        try:
            rows = await asyncio.wait_for(
                direct_search(query, limit, context=context),
                timeout=_DIRECT_STORE_TIMEOUT_SECONDS,
            )
            finish(success=rows is not None, count=len(rows or []), detail="direct")
            if rows is not None:
                now = time.monotonic()
                previous = _direct_cache.get(base_key)
                if previous is None or previous[1] <= limit or now - previous[0] >= (
                    _DIRECT_CACHE_TTL_SECONDS if previous[2] else _DIRECT_EMPTY_TTL_SECONDS
                ):
                    _direct_cache[base_key] = (now, limit, deepcopy(rows))
                for key, (created, _, cached_rows) in list(_direct_cache.items()):
                    ttl = _DIRECT_CACHE_TTL_SECONDS if cached_rows else _DIRECT_EMPTY_TTL_SECONDS
                    if now - created >= ttl:
                        _direct_cache.pop(key, None)
                while len(_direct_cache) > _DIRECT_CACHE_MAX_ENTRIES:
                    _direct_cache.pop(next(iter(_direct_cache)))
            return rows
        except Exception as exc:
            finish(success=False, detail=f"{type(exc).__name__}: {exc}")
            print(f"{store_name}: DIRECT ERROR {type(exc).__name__}", flush=True)
            return None
    finally:
        _direct_inflight.pop(task_key, None)


async def scrape_query(
    query: str,
    stores: list[str] | None,
    limit: int,
    headless: bool,
    engine: str = "camoufox",
    context: dict | None = None,
):
    result = await scrape_query_with_status(query, stores, limit, headless, engine, context)
    return result.rows


async def scrape_query_with_status(
    query: str,
    stores: list[str] | None,
    limit: int,
    headless: bool,
    engine: str = "camoufox",
    context: dict | None = None,
) -> SearchQueryResult:
    selected_stores = resolve_stores(stores)
    # Coordinates only select a branch before this point. Including them here
    # would create a distinct cache entry for every GPS reading.
    cache_context = {
        key: value
        for key, value in (context or {}).items()
        if key not in {"latitude", "longitude", "location_accuracy_meters"}
    }
    context_key = tuple(sorted(cache_context.items()))
    cache_key = (query.strip().casefold(), tuple(selected_stores), limit, headless, engine, context_key)
    cached = _search_cache.get(cache_key)
    now = time.monotonic()
    if cached and now - cached[0] < _SEARCH_CACHE_TTL_SECONDS:
        return SearchQueryResult(list(cached[1].rows), dict(cached[1].source_status))

    task = _search_inflight.get(cache_key)
    if task is None:
        task = asyncio.create_task(_scrape_and_cache(cache_key, query, selected_stores, limit, headless, engine, context))
        _search_inflight[cache_key] = task
    result = await asyncio.shield(task)
    return SearchQueryResult(list(result.rows), dict(result.source_status))


async def _scrape_and_cache(cache_key, query, selected_stores, limit, headless, engine, context):
    try:
        result = await _scrape_query_uncached(query, selected_stores, limit, headless, engine, context)
        # An empty result may be a transient upstream failure, so retry on the next request.
        if result.rows and "error" not in result.source_status.values():
            _search_cache[cache_key] = (time.monotonic(), result)
        now = time.monotonic()
        for key, (created, _) in list(_search_cache.items()):
            if now - created >= _SEARCH_CACHE_TTL_SECONDS:
                _search_cache.pop(key, None)
        while len(_search_cache) > _SEARCH_CACHE_MAX_ENTRIES:
            _search_cache.pop(next(iter(_search_cache)))
        return result
    finally:
        _search_inflight.pop(cache_key, None)


async def _scrape_query_uncached(query, selected_stores, limit, headless, engine, context=None):
    direct_tasks = [
        asyncio.create_task(_search_one_direct_store(store, query, limit, context))
        for store in selected_stores
    ]
    direct_results = await asyncio.gather(*direct_tasks)

    rows = []
    source_status = {}
    browser_stores = []
    for store_name, result in zip(selected_stores, direct_results):
        if result is None:
            browser_stores.append(store_name)
            continue
        rows.extend(result)
        source_status[store_name] = "ok"
        print(f"{store_name}: {len(result)} productos directos", flush=True)

    if not browser_stores:
        return SearchQueryResult(rows, source_status)

    try:
        async with open_browser(headless=headless, engine=engine) as browser:
            browser_result = await scrape_query_with_browser(browser, query, browser_stores, limit)
        rows.extend(browser_result.rows)
        source_status.update(browser_result.source_status)
    except Exception as exc:
        print(f"Browser search: ERROR {type(exc).__name__}", flush=True)
        source_status.update({store: "error" for store in browser_stores})
    return SearchQueryResult(rows, source_status)
