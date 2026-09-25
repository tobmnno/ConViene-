from __future__ import annotations

from models import CartItem, CartItemMatch, CompareResponse, StoreTotal
import asyncio

from services.catalog import products_are_comparable, rank_search_results, search_query_for_product_name
from services.scraper import resolve_stores, scrape_query


async def compare_cart(
    items: list[CartItem],
    stores: list[str] | None,
    limit: int,
    headless: bool,
    engine: str = "camoufox",
):
    selected_stores = resolve_stores(stores)
    totals = {store: 0.0 for store in selected_stores}
    found_items = {store: 0 for store in selected_stores}
    item_results: list[CartItemMatch] = []

    async def compare_item(item):
        search_query = search_query_for_product_name(item.name)
        rows = await scrape_query(search_query, selected_stores, limit, headless, engine)
        matches = [
            match
            for match in rank_search_results(item.name, rows, limit=limit)
            if products_are_comparable(item.name, match.product.name)
        ]
        return item, matches

    compared_items = await asyncio.gather(*(compare_item(item) for item in items))
    for item, matches in compared_items:

        best_by_store = {}
        for match in matches:
            if match.product.store not in best_by_store:
                best_by_store[match.product.store] = match

        chosen = matches[0] if matches else None
        item_results.append(CartItemMatch(item=item, matches=matches, chosen=chosen))

        for store in selected_stores:
            best_match = best_by_store.get(store)
            if best_match is None or best_match.product.price is None:
                continue
            totals[store] += best_match.product.price * item.quantity
            found_items[store] += 1

    ranking = sorted(
        [
            StoreTotal(
                store=store,
                total=round(totals[store], 2),
                items_found=found_items[store],
                items_total=len(items),
                missing_items=len(items) - found_items[store],
            )
            for store in selected_stores
        ],
        key=lambda row: (row.missing_items, row.total, row.store),
    )

    return CompareResponse(items=item_results, ranking=ranking, stores=selected_stores, items_count=len(items))
