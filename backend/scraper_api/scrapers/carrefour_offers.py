"""Only publish quantity offers confirmed by Carrefour's cart simulation."""

from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
import logging
import re
import time

import requests

from models import QuantityOffer
from services.catalog import valid_gtin
from services.monitoring import timed_check

logger = logging.getLogger(__name__)
SIMULATION_URL = "https://www.carrefour.com.ar/api/checkout/pub/orderForms/simulation"
_NAME = "<Name>k__BackingField"
_CONDITIONS = "<Conditions>k__BackingField"
_MINIMUM = "<MinimumQuantity>k__BackingField"
_PARAMETERS = "<Parameters>k__BackingField"


def _mechanic(teaser: dict):
    name = str(teaser.get(_NAME) or "")
    conditions = teaser.get(_CONDITIONS) or {}
    if conditions.get(_PARAMETERS):
        return None
    minimum = conditions.get(_MINIMUM)
    bundles = re.findall(r"(?<!\d)([23])\s*x\s*([12])(?!\d)", name, re.I)
    second = re.findall(r"(\d{1,3})\s*%\s*(?:de\s*)?(?:descuento\s*)?(?:en\s*)?(?:la\s*)?(?:2da|segunda)\s*unidad", name, re.I)
    if len(bundles) == 1 and not second:
        required, charged = map(int, bundles[0])
        if required == minimum and charged < required:
            return "buy_n_pay_m", required, charged, 0.0, name
    if len(second) == 1 and not bundles and minimum == 2:
        percentage = float(second[0])
        if 0 < percentage <= 100:
            return "second_unit_discount", 2, 1, percentage, name
    return None


def has_quantity_teaser(offer: dict):
    return any(_mechanic(teaser) for teaser in offer.get("Teasers") or []
               if isinstance(teaser, dict))


def _simulate(item_id: str, seller_id: str, channel: str, quantity: int, bucket: int):
    try:
        return _simulate_cached(item_id, seller_id, channel, quantity, bucket)
    except _SimulationUnavailable:
        return None


class _SimulationUnavailable(Exception):
    pass


@lru_cache(maxsize=512)
def _simulate_cached(item_id: str, seller_id: str, channel: str, quantity: int, bucket: int):
    try:
        response = requests.post(
            SIMULATION_URL,
            params={"sc": channel},
            json={"items": [{"id": item_id, "quantity": quantity, "seller": seller_id}], "country": "ARG"},
            timeout=8,
        )
        response.raise_for_status()
        data = response.json()
        items = data.get("items") or []
        if len(items) != 1 or str(items[0].get("id")) != item_id or items[0].get("quantity") != quantity:
            logger.warning("Carrefour cart simulation changed item structure for SKU %s", item_id)
            raise _SimulationUnavailable
        total = (items[0].get("priceDefinition") or {}).get("total")
        if not isinstance(total, (int, float)) or total <= 0:
            logger.warning("Carrefour cart simulation omitted a payable total for SKU %s", item_id)
            raise _SimulationUnavailable
        active = (data.get("ratesAndBenefitsData") or {}).get("rateAndBenefitsIdentifiers") or []
        names = frozenset(str(row.get("name") or "").strip().casefold()
                          for row in active if isinstance(row, dict))
        return int(total), names
    except (requests.RequestException, ValueError, TypeError, KeyError, AttributeError) as exc:
        logger.warning("Carrefour cart simulation unavailable for SKU %s: %s", item_id, exc)
        raise _SimulationUnavailable from exc


def verified_quantity_offers(item: dict, seller: dict, channel: str, product_url: str,
                             captured_at: str, catalog_price: float):
    ean = valid_gtin(str(item.get("ean") or ""))
    item_id = str(item.get("itemId") or "")
    seller_id = str(seller.get("sellerId") or "")
    offer = seller.get("commertialOffer") or {}
    if not (ean and item_id.isdigit() and seller_id and product_url.startswith("https://www.carrefour.com.ar/")):
        return []
    candidates = [_mechanic(teaser) for teaser in offer.get("Teasers") or [] if isinstance(teaser, dict)]
    candidates = [candidate for candidate in candidates if candidate]
    if len(candidates) != 1:
        return []

    finish = timed_check("carrefour_quantity_offers")
    mechanic, required, charged, percentage, teaser_name = candidates[0]
    bucket = int(time.time() // 900)
    first = _simulate(item_id, seller_id, channel, 1, bucket)
    if first is None:
        finish(success=False, detail="Cart simulation unavailable or changed schema")
        return []
    if abs(first[0] - round(catalog_price * 100)) > 1:
        logger.info("Carrefour catalog and checkout prices differ for SKU %s", item_id)
        finish(success=False, detail="Catalog and cart price mismatch")
        return []
    with ThreadPoolExecutor(max_workers=2) as executor:
        bundle_future = executor.submit(_simulate, item_id, seller_id, channel, required, bucket)
        extra_future = executor.submit(_simulate, item_id, seller_id, channel, required + 1, bucket)
        bundle, extra = bundle_future.result(), extra_future.result()
    if bundle is None or extra is None:
        finish(success=False, detail="Cart simulation unavailable or changed schema")
        return []
    active_name = teaser_name.strip().casefold()
    if active_name in first[1] or active_name not in bundle[1] or active_name not in extra[1]:
        finish(success=True, detail="Teaser did not activate as a same-SKU quantity offer", count=0)
        return []
    first, bundle, extra = first[0], bundle[0], extra[0]
    expected_bundle = (charged * first if mechanic == "buy_n_pay_m"
                       else round((2 - percentage / 100) * first))
    if abs(bundle - expected_bundle) > 1 or abs(extra - (bundle + first)) > 1:
        logger.info("Carrefour teaser is already priced per unit or has ambiguous rules for SKU %s", item_id)
        finish(success=True, detail="No additional same-SKU quantity discount", count=0)
        return []

    finish(success=True, count=1)
    return [QuantityOffer(
        id=f"carrefour-{channel}-{ean}-{mechanic}-{required}-{charged}-{int(percentage)}",
        mechanic=mechanic,
        required_quantity=required,
        charged_quantity=charged,
        second_unit_discount=percentage,
        source_url=product_url,
        captured_at=captured_at,
        branch_id=f"sales-channel-{channel}",
    )]
