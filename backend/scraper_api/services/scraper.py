from __future__ import annotations

import asyncio
import re
from contextlib import asynccontextmanager

from scrapers import SCRAPERS, STORE_NAMES

STORE_ALIASES = {
    "carrefour": "carrefour",
    "coto": "coto",
    "lagallega": "la_gallega",
    "la_gallega": "la_gallega",
    "la-gallega": "la_gallega",
    "la gallega": "la_gallega",
}


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
        return await SCRAPERS[store_name].search(page, query, limit)
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


async def _search_one_direct_store(store_name: str, query: str, limit: int):
    direct_search = getattr(SCRAPERS[store_name], "search_direct", None)
    if direct_search is None:
        return None
    try:
        return await direct_search(query, limit)
    except Exception as exc:
        print(f"{store_name}: DIRECT ERROR {type(exc).__name__}: {exc}", flush=True)
        return None


async def scrape_query(
    query: str,
    stores: list[str] | None,
    limit: int,
    headless: bool,
    engine: str = "camoufox",
):
    selected_stores = resolve_stores(stores)
    direct_tasks = [
        asyncio.create_task(_search_one_direct_store(store, query, limit))
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
