import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scrapers.stores import _coto_api_search, _coto_price, _coto_quantity_offers


def test_coto_prefers_large_official_product_image(monkeypatch):
    class Response:
        status_code = 200

        def json(self):
            return {"response": {"results": [{"value": "Leche Ilolay 1 L", "data": {
                "product_main_ean": "7790787002528",
                "product_list_price": 2799,
                "store_availability": ["200"],
                "image_url": "https://www.coto.com.ar/small.jpg",
                "product_large_image_url": "https://www.coto.com.ar/large.jpg",
            }}]}}

    monkeypatch.setattr("scrapers.stores.requests.get", lambda *args, **kwargs: Response())
    rows = _coto_api_search("leche", 20, {"coto_store": "200"})
    assert rows is not None and len(rows) == 1
    assert rows[0].image == "https://www.coto.com.ar/large.jpg"


def test_coto_two_for_one_uses_shelf_price_not_effective_unit_price():
    data = {
        "product_main_ean": "7798338291056",
        "product_list_price": 1980,
        "price": [{"store": "200", "listPrice": 1980}],
        "discounts": [{
            "id": "test-1", "takingText": "Llevando 2", "discountText": "2x1",
            "discountPrice": "$990.00", "regularPriceText": "Precio Contado: $1980",
        }],
    }
    offers = _coto_quantity_offers(data, "200", "https://www.coto.com.ar/productos/example", "2026-10-20T00:00:00Z")
    assert len(offers) == 1
    assert offers[0].required_quantity == 2
    assert offers[0].charged_quantity == 1
    assert offers[0].branch_id == "200"
    assert _coto_price(data, "200", bool(offers)) == (1980, None)


def test_coto_quantity_offer_rejects_unlinked_or_ambiguous_discounts():
    data = {
        "product_main_ean": "7798338291056",
        "discounts": [
            {"id": "a", "takingText": "Llevando 2", "discountText": "3x2"},
            {"id": "b", "takingText": "Llevando 2", "discountText": "2da con promo"},
        ],
    }
    assert _coto_quantity_offers(data, "200", "https://www.coto.com.ar/", "2026-10-20T00:00:00Z") == []
    data["product_main_ean"] = "invalid"
    data["discounts"] = [{"id": "c", "takingText": "Llevando 2", "discountText": "2x1"}]
    assert _coto_quantity_offers(data, "200", "https://www.coto.com.ar/", "2026-10-20T00:00:00Z") == []


@pytest.mark.parametrize("taking,label,mechanic,charged,second", [
    ("Llevando 3", "3x2", "buy_n_pay_m", 2, 0),
    ("Llevando 2", "70% 2da", "second_unit_discount", 1, 70),
])
def test_coto_other_structured_quantity_mechanics(taking, label, mechanic, charged, second):
    data = {"product_main_ean": "7798338291056", "discounts": [{
        "id": "live-format", "takingText": taking, "discountText": label,
    }]}
    offers = _coto_quantity_offers(data, "200", "https://www.coto.com.ar/", "2026-10-20T00:00:00Z")
    assert len(offers) == 1
    assert offers[0].mechanic == mechanic
    assert offers[0].charged_quantity == charged
    assert offers[0].second_unit_discount == second


@pytest.mark.skipif(os.getenv("RUN_LIVE_PROMO_TESTS") != "1", reason="Opt-in live source check")
def test_live_coto_catalog_exposes_ean_bound_quantity_offer():
    rows = _coto_api_search("leche", 50, {"coto_store": "200"})
    assert rows is not None
    offers = [(row, offer) for row in rows for offer in row.quantity_offers]
    assert offers, "Coto quantity-offer schema disappeared or no sample is currently active"
    assert all(row.ean and offer.branch_id == "200" for row, offer in offers)
    assert all(offer.source_url.startswith("https://www.coto.com.ar/") for _, offer in offers)
