from __future__ import annotations

from models import CartItem, CartItemMatch, CompareResponse, StoreTotal, EquivalentsRequest, ProductReference, ShoppingContext
import asyncio

from services.equivalents import find_equivalents
from services.scraper import resolve_stores


async def compare_cart(
    items: list[CartItem],
    stores: list[str] | None,
    limit: int,
    headless: bool,
    engine: str = "camoufox",
    context: ShoppingContext | None = None,
):
    selected_stores = resolve_stores(stores)
    totals = {store: 0.0 for store in selected_stores}
    found_items = {store: 0 for store in selected_stores}
    item_results: list[CartItemMatch] = []

    async def compare_item(item):
        response = await find_equivalents(EquivalentsRequest(
            product=ProductReference(name=item.name, ean=item.ean, brand=item.brand),
            stores=selected_stores, context=context or ShoppingContext(),
        ))
        return item, sorted(response.results, key=lambda match: match.product.price), response.store_status

    compared_items = await asyncio.gather(*(compare_item(item) for item in items))
    for item, matches, store_status in compared_items:

        best_by_store = {}
        for match in matches:
            if match.product.store not in best_by_store:
                best_by_store[match.product.store] = match

        chosen = matches[0] if matches else None
        item_results.append(CartItemMatch(item=item, matches=matches, chosen=chosen, store_status=store_status))

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
