from datetime import date, datetime, timezone
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import DiscountPromotion
from services.discounts import _lagallega_blink_promotions, _validated_promotions


def promotion(**overrides):
    fields = {
        "id": "scope-test", "store": "coto", "title": "20%", "percentage": 20,
        "weekdays": [5], "start_date": "2026-10-01", "end_date": "2026-10-31",
        "source_url": "https://www.coto.com.ar/descuentos", "scraped_at": "2026-10-30T12:00:00Z",
        "source_type": "official_api", "verification_status": "source_reported",
        "calculation_status": "estimate",
    }
    return DiscountPromotion(**(fields | overrides))


def test_channel_or_branch_limits_scope_even_if_catalog_id_is_known():
    rows = _validated_promotions([
        promotion(id="channel", channel="Digital"),
        promotion(id="branch", branch_ids=["200"]),
        promotion(id="unspecified"),
    ], [])
    assert [row.applicability_scope for row in rows] == ["restricted", "restricted", "unknown"]


def test_unverified_fallback_cannot_claim_general_applicability():
    rows = _validated_promotions([
        promotion(source_type="static_fallback", applicability_scope="general_confirmed")
    ], [])
    assert rows[0].applicability_scope == "unknown"


def test_official_explicit_general_scope_remains_available_when_unrestricted():
    rows = _validated_promotions([promotion(applicability_scope="general_confirmed")], [])
    assert rows[0].applicability_scope == "general_confirmed"


def test_fresh_external_feed_is_visible_but_not_accepted_as_official_evidence():
    today = date.today()
    catalog = {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "source_url": "https://www.blinkapp.com.ar/comercios/la-gallega",
        "benefits": [{
            "id": "example", "bankName": "Banco Santa Fe", "rewardRate": "20%",
            "cuando": "todos los dias", "validUntil": f"{today.year + 1}-12-31",
            "condicion": "20% con tarjeta",
        }],
    }
    rows = _lagallega_blink_promotions(catalog, today)
    assert len(rows) == 1
    assert rows[0].verification_status == "unverified"
    assert rows[0].calculation_status == "not_calculable"
    assert rows[0].applicability_scope == "unknown"
