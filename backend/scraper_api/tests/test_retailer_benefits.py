from datetime import date
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from unittest.mock import patch
import requests

from services.retailer_benefits import inspect_lareina_benefits, parse_jumbo_legals
from services.discounts import clear_discount_cache, scrape_discounts
from services.monitoring import status_snapshot


JUMBO_LEGAL = """
<p><span>1)CYBER JUMBO</span><br/>Cyber Monday. Promoción válida
exclusivamente para compras online realizadas del 02/11/2026 al 04/11/2026
inclusive. Hasta 2x1 en productos seleccionados de las categorías Almacén y
Bebidas. Las ofertas no son acumulables con reintegros bancarios.</p>
"""


def test_jumbo_campaign_is_visible_but_never_calculable_for_any_ean():
    rows = parse_jumbo_legals(JUMBO_LEGAL, date(2026, 11, 3))
    assert len(rows) == 1
    row = rows[0]
    assert row.store == "jumbo"
    assert row.start_date == "2026-11-02"
    assert row.end_date == "2026-11-04"
    assert row.product_eans == []
    assert row.calculation_status == "not_calculable"
    assert row.applicability_scope == "restricted"
    assert row.source_type == "official_page"
    assert row.channel == "online"


def test_jumbo_campaign_expires_and_ambiguous_page_is_ignored():
    assert parse_jumbo_legals(JUMBO_LEGAL, date(2026, 11, 5)) == []
    assert parse_jumbo_legals("<p>Hasta 2x1 en seleccionados</p>", date(2026, 11, 3)) == []


def test_lareina_expired_cards_are_not_presented_as_current():
    html = """
    <div class="promo-item"><div class="promo-desc"><p>
    TARJETA DE CRÉDITO NARANJA X. HASTA EL 31/10/26.
    </p></div></div>
    """
    audit = inspect_lareina_benefits(html, date(2026, 11, 3))
    assert audit.expired == 1
    assert audit.unverifiable == 0
    assert audit.parsed_cards == 1


def test_lareina_future_end_date_alone_cannot_verify_a_benefit():
    html = '<div class="promo-item"><p>25% OFF. HASTA EL 30/11/26.</p></div>'
    audit = inspect_lareina_benefits(html, date(2026, 11, 3))
    assert audit.unverifiable == 1
    assert audit.expired == 0


def test_discount_api_keeps_jumbo_campaign_out_of_price_calculation():
    class Response:
        content = JUMBO_LEGAL.encode()
        text = JUMBO_LEGAL

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", return_value=Response()):
        result = scrape_discounts(["jumbo"], date(2026, 11, 3))
    assert len(result.results) == 1
    assert result.results[0].calculation_status == "not_calculable"
    assert result.results[0].product_eans == []


def test_failed_retailer_page_is_not_confirmed_absence():
    clear_discount_cache()
    with patch("services.discounts.requests.get", side_effect=requests.Timeout):
        result = scrape_discounts(["jumbo", "lareina"], date(2026, 11, 3))
    assert result.results == []
    assert len(result.warnings) == 2
    assert all("no se pudieron leer descuentos" in warning for warning in result.warnings)


def test_expired_lareina_cards_do_not_create_promotions():
    html = '<div class="promo-item"><p>25% OFF. HASTA EL 31/10/26.</p></div>'

    class Response:
        content = html.encode()
        text = html

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", return_value=Response()):
        result = scrape_discounts(["lareina"], date(2026, 11, 3))
    assert result.results == []
    assert any("vencidos" in warning for warning in result.warnings)


def test_retailer_page_is_shared_when_selected_day_changes():
    class Response:
        content = JUMBO_LEGAL.encode()
        text = JUMBO_LEGAL

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", return_value=Response()) as get:
        first = scrape_discounts(["jumbo"], date(2026, 11, 3))
        second = scrape_discounts(["jumbo"], date(2026, 11, 4))
    assert len(first.results) == len(second.results) == 1
    assert get.call_count == 1


def test_retailer_page_failure_is_retried_on_next_day():
    class Response:
        content = JUMBO_LEGAL.encode()
        text = JUMBO_LEGAL

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", side_effect=[requests.Timeout(), Response()]) as get:
        failed = scrape_discounts(["jumbo"], date(2026, 11, 3))
        recovered = scrape_discounts(["jumbo"], date(2026, 11, 4))
    assert failed.results == []
    assert len(recovered.results) == 1
    assert get.call_count == 2


def test_concurrent_retailer_days_share_one_page_request():
    class Response:
        content = JUMBO_LEGAL.encode()
        text = JUMBO_LEGAL

        def raise_for_status(self):
            pass

    entered, release = Event(), Event()

    def fetch(*args, **kwargs):
        entered.set()
        assert release.wait(3)
        return Response()

    clear_discount_cache()
    with patch("services.discounts.requests.get", side_effect=fetch) as get:
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(scrape_discounts, ["jumbo"], date(2026, 11, 3))
            assert entered.wait(3)
            second = pool.submit(scrape_discounts, ["jumbo"], date(2026, 11, 4))
            release.set()
            assert len(first.result().results) == 1
            assert len(second.result().results) == 1
    assert get.call_count == 1


def test_expired_retailer_page_is_fetched_again():
    class Response:
        content = JUMBO_LEGAL.encode()
        text = JUMBO_LEGAL

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", return_value=Response()) as get:
        scrape_discounts(["jumbo"], date(2026, 11, 3))
        with patch("services.discounts.time.monotonic", return_value=10_000_000):
            scrape_discounts(["jumbo"], date(2026, 11, 4))
    assert get.call_count == 2


def test_expired_campaign_does_not_mark_healthy_legal_page_as_failed():
    class Response:
        content = JUMBO_LEGAL.encode()
        text = JUMBO_LEGAL

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", return_value=Response()):
        result = scrape_discounts(["jumbo"], date(2026, 11, 5))
    assert result.results == []
    source = status_snapshot()["sources"]["promotions.jumbo"]
    assert source["consecutive_failures"] == 0


def test_structurally_broken_page_is_not_cached_as_a_valid_source():
    class Response:
        def __init__(self, html):
            self.content = html.encode()
            self.text = html

        def raise_for_status(self):
            pass

    clear_discount_cache()
    with patch("services.discounts.requests.get", side_effect=[
        Response("<html><p>Temporarily unavailable</p></html>"),
        Response(JUMBO_LEGAL),
    ]) as get:
        first = scrape_discounts(["jumbo"], date(2026, 11, 3))
        recovered = scrape_discounts(["jumbo"], date(2026, 11, 4))
    assert first.results == []
    assert len(recovered.results) == 1
    assert get.call_count == 2
