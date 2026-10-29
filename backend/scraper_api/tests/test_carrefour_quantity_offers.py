import sys
from pathlib import Path
from threading import Barrier
from unittest.mock import patch

import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scrapers.carrefour_offers import _mechanic, _simulate, verified_quantity_offers
from scrapers.stores import _carrefour_api_search

EAN = "8445292446327"
URL = "https://www.carrefour.com.ar/chocolate/p"
CAPTURED = "2026-10-22T15:00:00+00:00"


def product(teaser="PROMO-2x1 Combinable NESTLE"):
    item = {"ean": EAN, "itemId": "299553"}
    seller = {"sellerId": "1", "commertialOffer": {
        "Price": 1599.0, "IsAvailable": True,
        "Teasers": [{
            "<Name>k__BackingField": teaser,
            "<Conditions>k__BackingField": {
                "<MinimumQuantity>k__BackingField": 2,
                "<Parameters>k__BackingField": [],
            },
        }],
    }}
    item["sellers"] = [seller]
    return item, seller


def test_checkout_only_accepts_actual_two_for_one():
    item, seller = product()
    totals = {
        1: (159900, frozenset()),
        2: (159900, frozenset({"promo-2x1 combinable nestle"})),
        3: (319800, frozenset({"promo-2x1 combinable nestle"})),
    }
    with patch("scrapers.carrefour_offers._simulate", side_effect=lambda *args: totals[args[3]]) as simulate:
        offers = verified_quantity_offers(item, seller, "1", URL, CAPTURED, 1599.0)
    assert len(offers) == 1
    assert (offers[0].required_quantity, offers[0].charged_quantity) == (2, 1)
    assert offers[0].branch_id == "sales-channel-1"
    assert simulate.call_count == 3


def test_live_shape_half_price_with_one_unit_is_not_double_discounted():
    item, seller = product()
    totals = {
        1: (79950, frozenset()),
        2: (159900, frozenset({"promo-2x1 combinable nestle"})),
        3: (239850, frozenset({"promo-2x1 combinable nestle"})),
    }
    with patch("scrapers.carrefour_offers._simulate", side_effect=lambda *args: totals[args[3]]) as simulate:
        assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 799.5) == []
    assert simulate.call_count == 3


def test_three_for_two_and_second_unit_require_checkout_confirmation():
    item, seller = product("PROMO-3x2")
    seller["commertialOffer"]["Teasers"][0]["<Conditions>k__BackingField"]["<MinimumQuantity>k__BackingField"] = 3
    totals = {
        1: (10000, frozenset()),
        3: (20000, frozenset({"promo-3x2"})),
        4: (30000, frozenset({"promo-3x2"})),
    }
    with patch("scrapers.carrefour_offers._simulate", side_effect=lambda *args: totals[args[3]]):
        assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 100)[0].charged_quantity == 2
    item, seller = product("50% segunda unidad")
    totals = {
        1: (10000, frozenset()),
        2: (15000, frozenset({"50% segunda unidad"})),
        3: (25000, frozenset({"50% segunda unidad"})),
    }
    with patch("scrapers.carrefour_offers._simulate", side_effect=lambda *args: totals[args[3]]):
        assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 100)[0].second_unit_discount == 50


def test_bundle_and_extra_are_simulated_concurrently():
    item, seller = product()
    workers = Barrier(2)

    def simulate(_item, _seller, _channel, quantity, _bucket):
        if quantity == 1:
            return 159900, frozenset()
        workers.wait(timeout=2)
        total = 159900 if quantity == 2 else 319800
        return total, frozenset({"promo-2x1 combinable nestle"})

    with patch("scrapers.carrefour_offers._simulate", side_effect=simulate):
        assert len(verified_quantity_offers(item, seller, "1", URL, CAPTURED, 1599.0)) == 1


def test_ambiguous_or_payment_condition_fails_closed():
    item, seller = product("Tarjeta 2x1")
    seller["commertialOffer"]["Teasers"][0]["<Conditions>k__BackingField"]["<Parameters>k__BackingField"] = [
        {"<Name>k__BackingField": "RestrictionsBins"}
    ]
    assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 1599) == []
    item, seller = product("2x1 y 3x2")
    assert _mechanic(seller["commertialOffer"]["Teasers"][0]) is None
    assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 1599) == []


def test_checkout_failure_or_price_mismatch_preserves_catalog_price():
    item, seller = product()
    with patch("scrapers.carrefour_offers.timed_check") as timed, patch("scrapers.carrefour_offers._simulate", return_value=None) as simulate:
        assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 1599) == []
    assert simulate.call_count == 1
    timed.return_value.assert_called_once_with(
        success=False, detail="Cart simulation unavailable or changed schema"
    )
    with patch("scrapers.carrefour_offers._simulate", return_value=(10000, frozenset())) as simulate:
        assert verified_quantity_offers(item, seller, "1", URL, CAPTURED, 1599) == []
    assert simulate.call_count == 1


def test_search_retains_price_when_historical_cluster_mentions_two_for_one():
    item, _ = product()
    response = [{"productName": "Chocolate Crunch 22 grs", "productClusters": {"old": "2x1 2024"},
                 "link": URL, "items": [item]}]
    with patch("scrapers.stores.requests.get") as get, patch("scrapers.stores.verified_quantity_offers", return_value=[]) as verify:
        get.return_value.status_code = 200
        get.return_value.json.return_value = response
        rows = _carrefour_api_search("chocolate", 10)
    assert rows[0].price == 1599
    assert rows[0].promo_text is None
    assert rows[0].quantity_offers == []
    verify.assert_called_once()


def test_failed_cart_simulation_is_retried_within_same_time_bucket():
    if hasattr(_simulate, "cache_clear"):
        _simulate.cache_clear()
    with patch("scrapers.carrefour_offers.requests.post") as post:
        valid = post.return_value
        valid.raise_for_status.return_value = None
        valid.json.return_value = {
            "items": [{"id": "299553", "quantity": 2,
                       "priceDefinition": {"total": 159900}}],
            "ratesAndBenefitsData": {"rateAndBenefitsIdentifiers": []},
        }
        post.side_effect = [requests.ConnectionError("temporary"), valid]
        assert _simulate("299553", "1", "1", 2, 12345) is None
        assert _simulate("299553", "1", "1", 2, 12345) == (159900, frozenset())
        assert post.call_count == 2
