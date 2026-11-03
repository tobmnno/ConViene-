"""Opt-in schema checks against public promotion sources.

Run with RUN_LIVE_PROMO_TESTS=1; these tests intentionally fail if a source
changes structure or stops responding. They do not assert particular offers.
"""

import os
import sys
from pathlib import Path

import pytest
import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.discounts import (
    COTO_PROMOTIONS_URL,
    LAGALLEGA_URL,
    _master_data,
)
from services.refresh import LAGALLEGA_BLINK_URL
from services.retailer_benefits import (
    JUMBO_LEGALS_URL,
    LAREINA_BENEFITS_URL,
    _PageParagraphs,
    inspect_lareina_benefits,
)
from datetime import date
from scrapers.stores import REQUEST_HEADERS
from scrapers.carrefour_offers import SIMULATION_URL


pytestmark = pytest.mark.skipif(
    os.getenv("RUN_LIVE_PROMO_TESTS") != "1",
    reason="Set RUN_LIVE_PROMO_TESTS=1 to check live promotion sources",
)


def test_coto_structured_promotions_source():
    response = requests.get(COTO_PROMOTIONS_URL, headers=REQUEST_HEADERS, timeout=25)
    response.raise_for_status()
    result = response.json().get("result")
    assert isinstance(result, dict)
    assert isinstance(result.get("promocionesDigitales"), list)
    assert isinstance(result.get("promocionesSucursalesFisicas"), list)
    assert any(result.get(key) for key in ("promocionesDigitales", "promocionesSucursalesFisicas"))


def test_carrefour_structured_promotions_source():
    rows = _master_data("BP", "id,title,active,active_from,active_to,valid", where="active=true")
    assert rows
    assert all(row.get("id") and row.get("title") for row in rows)


def test_carrefour_public_cart_simulation_contract():
    catalog = requests.get(
        "https://www.carrefour.com.ar/api/catalog_system/pub/products/search/chocolate",
        params={"_from": 0, "_to": 9, "sc": 1}, headers=REQUEST_HEADERS, timeout=25,
    )
    catalog.raise_for_status()
    sku = next((item for product in catalog.json() for item in product.get("items") or []
                if item.get("itemId") and item.get("sellers")), None)
    assert sku is not None, "Carrefour product search no longer exposes SKUs"
    seller = sku["sellers"][0]
    response = requests.post(
        SIMULATION_URL, params={"sc": 1},
        json={"items": [{"id": str(sku["itemId"]), "quantity": 1,
                         "seller": str(seller["sellerId"])}], "country": "ARG"},
        timeout=25,
    )
    response.raise_for_status()
    result = response.json()
    assert result["items"][0]["priceDefinition"]["total"] > 0
    assert isinstance(result["ratesAndBenefitsData"]["rateAndBenefitsIdentifiers"], list)


def test_lagallega_public_page_and_external_feed():
    official = requests.get(LAGALLEGA_URL, timeout=25)
    official.raise_for_status()
    assert "Beneficios" in official.text or "POR BENEFICIO" in official.text

    feed = requests.get(LAGALLEGA_BLINK_URL, timeout=25)
    feed.raise_for_status()
    assert 'id="blink-merchant-bootstrap"' in feed.text


def test_jumbo_official_legals_page_contract():
    response = requests.get(JUMBO_LEGALS_URL, headers=REQUEST_HEADERS, timeout=25)
    response.raise_for_status()
    paragraphs = [text for text, _ in _PageParagraphs(response.text).paragraphs]
    assert paragraphs, "Jumbo legal page no longer exposes readable paragraphs"
    assert any("JUMBO" in text.upper() for text in paragraphs)


def test_lareina_official_benefits_page_contract():
    response = requests.get(LAREINA_BENEFITS_URL, headers=REQUEST_HEADERS, timeout=25)
    response.raise_for_status()
    audit = inspect_lareina_benefits(response.text, date.today())
    assert audit.parsed_cards > 0, "La Reina benefits cards changed structure"
