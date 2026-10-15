from __future__ import annotations

import asyncio
from datetime import datetime, timezone
import re
import time

from models import EquivalentsRequest, EquivalentsResponse
from services.catalog import (alternative_match, normalize_text, product_category, same_catalog_product,
                              score_product_match, search_query_for_product_name,
                              valid_gtin)
from services.scraper import _search_one_direct_store, resolve_stores

_cache: dict[tuple, tuple[float, EquivalentsResponse]] = {}
_inflight: dict[tuple, asyncio.Task[EquivalentsResponse]] = {}
_slots = asyncio.Semaphore(8)
_CACHE_TTL = 120
_CACHE_MAX_ENTRIES = 256


async def _query_store(store, query, context):
    async with _slots:
        return await _search_one_direct_store(store, query, 50, {**context, "equivalence_search": True})


def reference_queries(reference) -> list[str]:
    normalized = normalize_text(reference.name)
    words = normalized.text.split()
    product_types = {"leche", "crema", "dulce", "galletita", "galleta", "fideo", "yerba",
                     "cafe", "aceite", "arroz", "yogur", "cerveza", "gaseosa", "preservativo"}
    kind = next((word for word in words if word in product_types), words[0] if words else reference.name)
    if kind in {"crema", "dulce"} and "leche" in words:
        kind += " de leche"
    brand = normalize_text(reference.brand or "").text
    if not brand or brand in product_types:
        known_brands = ("serenisima", "tres ninas", "ilolay", "paulina", "tregar",
                        "oreo", "chocolinas", "cerealitas", "taragui", "coca cola")
        brand = next((name for name in known_brands if name in normalized.text), "")
    if not brand:
        # Keep distinctive words in their original order, never alphabetically.
        ignored = product_types | {"entera", "descremada", "liviana", "larga", "vida",
                                   "sachet", "brick", "tetra", "fortificada", "uat", "uht",
                                   "superfino", "ultrafino", "texturado", "lubricado",
                                   "extralubricado", "retardante", "natural", "tachas",
                                   "regular", "light", "diet", "zero", "original"}
        brand = " ".join(word for word in words if word not in ignored and not word.isdigit())[:100]
    size = ""
    if normalized.size_value is not None:
        size = f"{normalized.size_value:g}"
        if normalized.size_unit == "ml" and normalized.size_value >= 1000:
            size = f"{normalized.size_value / 1000:g}"
    compact = " ".join(part for part in (kind, brand, size) if part)
    clean = search_query_for_product_name(reference.name)
    broad = " ".join(part for part in (kind, brand) if part)
    candidates = [reference.ean if valid_gtin(reference.ean) else "", compact, clean, broad]
    # The legacy La Gallega catalog indexes '3' and 'tres' inconsistently.
    if "tres ninas" in compact:
        candidates[2] = re.sub(r"tres ninas", "3", compact)
    return list(dict.fromkeys(query for query in candidates if query))[:4]


async def _find_in_store(reference, store, context):
    queries = reference_queries(reference)
    responses = []
    if valid_gtin(reference.ean):
        ean_query = queries.pop(0)
        rows = await _query_store(store, ean_query, context)
        responses.append((ean_query, rows))
        exact = [row for row in rows or []
                 if valid_gtin(row.ean) == valid_gtin(reference.ean)
                 and same_catalog_product(reference, row)]
        if exact:
            available = [row for row in exact if row.available is not False and row.price and row.price > 0]
            if available:
                match = score_product_match(reference.name, min(available, key=lambda row: row.price))
                match.score, match.match_type = 100, "exact"
                return match, "found", []
    broad_query = queries.pop() if len(queries) > 1 else None
    responses.extend(zip(queries, await asyncio.gather(*[
        _query_store(store, query, context) for query in queries
    ])))

    def matching_rows():
        compatible = {}
        for _, rows in responses:
            for product in rows or []:
                if same_catalog_product(reference, product):
                    compatible[product.url or product.name] = product
        available = [row for row in compatible.values()
                     if row.available is not False and row.price is not None and row.price > 0]
        return compatible, available

    compatible, available = matching_rows()
    if not available and broad_query and any(rows is not None for _, rows in responses):
        responses.append((broad_query, await _query_store(store, broad_query, context)))
        compatible, available = matching_rows()
    if not available and any(rows is not None for _, rows in responses):
        failed = [(index, query) for index, (query, rows) in enumerate(responses) if rows is None][:2]
        if failed:
            retried = await asyncio.gather(*[
                _query_store(store, query, context) for _, query in failed
            ])
            for (index, query), rows in zip(failed, retried):
                responses[index] = (query, rows)
            compatible, available = matching_rows()
    if available:
        best = min(available, key=lambda row: row.price)
        match = score_product_match(reference.name, best)
        match.match_type = "same_product"
        if valid_gtin(reference.ean) == valid_gtin(best.ean) and valid_gtin(best.ean):
            match.score = 100
            match.match_type = "exact"
        return match, "found", []
    category = product_category(normalize_text(reference.name))
    if category and any(rows is not None for _, rows in responses):
        fallback_rows = await _query_store(store, category, context)
        responses.append((category, fallback_rows))
    suggestions = {}
    for _, rows in responses:
        for row in rows or []:
            if row.available is False or row.price is None or row.price <= 0:
                continue
            suggestion = alternative_match(reference, row)
            if suggestion:
                suggestions[row.ean or row.url or row.name] = suggestion
    ranked_suggestions = sorted(suggestions.values(), key=lambda row: (-row.score, row.product.price))[:2]
    # A failed attempt could be the only query that finds a differently named SKU.
    if any(rows is None for _, rows in responses):
        return None, "error", ranked_suggestions
    return None, "unavailable" if compatible else "not_found", ranked_suggestions


async def find_equivalents(payload: EquivalentsRequest) -> EquivalentsResponse:
    stores = resolve_stores(payload.stores)
    context = payload.context.model_dump(exclude_none=True)
    key = (payload.product.model_dump_json(), tuple(stores),
           tuple(sorted((k, v) for k, v in context.items() if k not in {"latitude", "longitude"})))
    now = time.monotonic()
    cached = _cache.get(key)
    if cached and now - cached[0] < _CACHE_TTL:
        return cached[1]
    task = _inflight.get(key)
    if task is None:
        task = asyncio.create_task(_compute_equivalents(key, payload, stores, context))
        _inflight[key] = task
    return await asyncio.shield(task)


async def _compute_equivalents(key, payload, stores, context) -> EquivalentsResponse:
    try:
        rows = await asyncio.gather(*[_find_in_store(payload.product, store, context) for store in stores])
        response = EquivalentsResponse(
            results=[match for match, _, _ in rows if match is not None],
            alternatives=[suggestion for _, _, suggestions in rows for suggestion in suggestions],
            store_status={store: status for store, (_, status, _) in zip(stores, rows)},
            checked_at=datetime.now(timezone.utc).isoformat(),
        )
        if "error" not in response.store_status.values():
            _cache[key] = (time.monotonic(), response)
        for old_key, (created, _) in list(_cache.items()):
            if time.monotonic() - created >= _CACHE_TTL:
                _cache.pop(old_key, None)
        while len(_cache) > _CACHE_MAX_ENTRIES:
            _cache.pop(next(iter(_cache)))
        return response
    finally:
        _inflight.pop(key, None)
