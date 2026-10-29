import sys
from datetime import date
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import DiscountPromotion
from services.discounts import clear_discount_cache, scrape_discounts


def test_failed_source_is_retried_before_healthy_cache_expires():
    clear_discount_cache()
    clock = [1000.0]
    with patch("services.discounts.time.monotonic", side_effect=lambda: clock[0]), patch(
        "services.discounts._scrape_coto", side_effect=[RuntimeError("offline"), []]
    ) as source:
        first = scrape_discounts(["coto"], date(2026, 10, 27))
        assert first.warnings
        clock[0] += 121
        scrape_discounts(["coto"], date(2026, 10, 27))
        assert source.call_count == 2
    clear_discount_cache()


def test_confirmed_response_keeps_five_minute_cache():
    clear_discount_cache()
    clock = [2000.0]
    promotion = DiscountPromotion(
        id="test-coto", store="coto", title="Beneficio de prueba",
        percentage=10, weekdays=[2], start_date="2026-10-01",
        end_date="2026-10-31", source_url="https://www.coto.com.ar/descuentos",
        scraped_at="2026-10-27T12:00:00Z",
    )
    with patch("services.discounts.time.monotonic", side_effect=lambda: clock[0]), patch(
        "services.discounts._scrape_coto", return_value=[promotion]
    ) as source:
        first = scrape_discounts(["coto"], date(2026, 10, 27))
        assert first.count == 1
        clock[0] += 121
        scrape_discounts(["coto"], date(2026, 10, 27))
        assert source.call_count == 1
        clock[0] += 180
        scrape_discounts(["coto"], date(2026, 10, 27))
        assert source.call_count == 2
    clear_discount_cache()
