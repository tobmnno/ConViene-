from __future__ import annotations

import asyncio
from datetime import datetime, timezone
import re
import time

from models import EquivalentsRequest, EquivalentsResponse
from services.catalog import (normalize_text, same_catalog_product,
                              score_product_match, search_query_for_product_name,
                              valid_gtin)
from services.scraper import _search_one_direct_store, resolve_stores

_cache: dict[tuple, tuple[float, EquivalentsResponse]] = {}
_locks: dict[tuple, asyncio.Lock] = {}
_slots = asyncio.Semaphore(8)


async def _query_store(store, query, context):
    async with _slots:
        return await _search_one_direct_store(store, query, 50, {**context, "equivalence_search": True})


def reference_queries(reference) -> list[str]:
    normalized = normalize_text(reference.name)
    words = normalized.text.split()
    product_types = {"leche", "crema", "dulce", "galletitas", "galletas", "yerba",
                     "cafe", "aceite", "arroz", "yogur", "cerveza", "gaseosa"}
    kind = next((word for word in words if word in product_types), words[0] if words else reference.name)
    if kind in {"crema", "dulce"} and "leche" in words:
        kind += " leche"
    brand = normalize_text(reference.brand or "").text
    if not brand or brand in product_types:
        known_brands = ("serenisima", "tres ninas", "ilolay", "paulina", "tregar",
                        "oreo", "chocolinas", "cerealitas", "taragui", "coca cola")
        brand = next((name for name in known_brands if name in normalized.text), "")
    if not brand:
        # Keep distinctive words in their original order, never alphabetically.
        ignored = product_types | {"entera", "descremada", "liviana", "larga", "vida",
                                   "sachet", "brick", "tetra", "fortificada", "uat", "uht"}
        brand = " ".join(word for word in words if word not in ignored)[:100]
    size = ""
    if normalized.size_value is not None:
        size = f"{normalized.size_value:g}"
        if normalized.size_unit == "ml" and normalized.size_value >= 1000:
            size = f"{normalized.size_value / 1000:g}"
    compact = " ".join(part for part in (kind, brand, size) if part)
    clean = search_query_for_product_name(reference.name)
    candidates = [reference.ean if valid_gtin(reference.ean) else "", compact, clean]
    # The legacy La Gallega catalog indexes '3' and 'tres' inconsistently.
    if "tres ninas" in compact:
        candidates[-1] = re.sub(r"tres ninas", "3", compact)
    return list(dict.fromkeys(query for query in candidates if query))[:3]


async def _find_in_store(reference, store, context):
    queries = reference_queries(reference)
    responses = []
    if valid_gtin(reference.ean):
        rows = await _query_store(store, queries.pop(0), context)
        responses.append(rows)
        exact = [row for row in rows or [] if valid_gtin(row.ean) == valid_gtin(reference.ean)]
        if exact:
            available = [row for row in exact if row.available is not False and row.price and row.price > 0]
            if not available:
                return None, "unavailable"
            match = score_product_match(reference.name, min(available, key=lambda row: row.price))
            match.score, match.match_type = 100, "exact"
            return match, "found"
    responses.extend(await asyncio.gather(*[
        _query_store(store, query, context) for query in queries
    ]))
    compatible = {}
    for rows in responses:
        for product in rows or []:
            if same_catalog_product(reference, product):
                compatible[product.url or product.name] = product
    available = [row for row in compatible.values()
                 if row.available is not False and row.price is not None and row.price > 0]
    if available:
        best = min(available, key=lambda row: row.price)
        match = score_product_match(reference.name, best)
        match.match_type = "exact"
        if valid_gtin(reference.ean) == valid_gtin(best.ean) and valid_gtin(best.ean):
            match.score = 100
        return match, "found"
    if compatible:
        return None, "unavailable"
    # A failed attempt could be the only query that finds a differently named SKU.
    return None, "error" if any(rows is None for rows in responses) else "not_found"


async def find_equivalents(payload: EquivalentsRequest) -> EquivalentsResponse:
    stores = resolve_stores(payload.stores)
    context = payload.context.model_dump(exclude_none=True)
    key = (payload.product.model_dump_json(), tuple(stores),
           tuple(sorted((k, v) for k, v in context.items() if k not in {"latitude", "longitude"})))
    now = time.monotonic()
    async with _locks.setdefault(key, asyncio.Lock()):
        cached = _cache.get(key)
        if cached and now - cached[0] < 120:
            return cached[1]
        rows = await asyncio.gather(*[_find_in_store(payload.product, store, context) for store in stores])
        response = EquivalentsResponse(
            results=[match for match, _ in rows if match is not None],
            store_status={store: status for store, (_, status) in zip(stores, rows)},
            checked_at=datetime.now(timezone.utc).isoformat(),
        )
        if "error" not in response.store_status.values():
            _cache[key] = (time.monotonic(), response)
        for old_key, (created, _) in list(_cache.items()):
            if time.monotonic() - created >= 120:
                _cache.pop(old_key, None)
                if old_key != key:
                    _locks.pop(old_key, None)
        return response
