import asyncio
from datetime import datetime, timezone
import sys
from unittest.mock import patch

from models import DiscountPromotion, DiscountsResponse, Product
from tools import source_watch
from tools.source_watch import _catalog_check, advance_state, confirmed_product_offer, offer_record, offer_summary


def _offer(**changes):
    fields = dict(
        id="official-1", store="jumbo", title="Leche 2x1", scraped_at="2026-11-04T10:00:00Z",
        start_date="2026-11-01", end_date="2026-11-30",
        weekdays=list(range(1, 8)),
        source_url="https://www.jumbo.com.ar/legales", product_eans=["7790742358608"],
        promotion_kind="store_product", mechanic="buy_n_pay_m", required_quantity=2,
        charged_quantity=1, source_type="official_api", verification_status="source_reported",
        calculation_status="exact", applicability_scope="general_confirmed",
    )
    fields.update(changes)
    return DiscountPromotion(**fields)


def test_product_offer_requires_official_ean_scope_and_current_dates():
    from datetime import date

    today = date(2026, 11, 4)
    assert confirmed_product_offer(_offer(), today)
    assert not confirmed_product_offer(_offer(product_eans=[]), today)
    assert not confirmed_product_offer(_offer(source_url="https://example.com/offer"), today)
    assert not confirmed_product_offer(_offer(calculation_status="not_calculable"), today)
    assert not confirmed_product_offer(_offer(applicability_scope="restricted"), today)
    assert confirmed_product_offer(_offer(applicability_scope="restricted", branch_ids=["1"], channel="online"), today)
    assert not confirmed_product_offer(_offer(end_date="2026-11-03"), today)
    assert not confirmed_product_offer(_offer(charged_quantity=2), today)
    assert not confirmed_product_offer(_offer(weekdays=[1]), today)
    assert not confirmed_product_offer(_offer(mechanic="second_unit_discount", second_unit_discount=0), today)
    assert not confirmed_product_offer(_offer(mechanic="fixed_bundle_price", bundle_price=0), today)


def test_two_failures_alert_once_and_recovery_once():
    messages = []
    send = lambda message: messages.append(message) or True
    now = datetime(2026, 11, 4, 12, tzinfo=timezone.utc)
    state = advance_state({}, {"products.coto": False}, [], now, send)
    assert messages == []
    advance_state(state, {"products.coto": False}, [], now, send)
    advance_state(state, {"products.coto": False}, [], now, send)
    assert len(messages) == 1
    advance_state(state, {"products.coto": True}, [], now, send)
    advance_state(state, {"products.coto": True}, [], now, send)
    assert len(messages) == 2
    assert "volvió" in messages[-1]


def test_failed_delivery_is_retried_not_marked_sent():
    now = datetime(2026, 11, 4, 12, tzinfo=timezone.utc)
    state = {"sources": {"products.coto": {"failures": 1, "alerted": False}}}
    advance_state(state, {"products.coto": False}, [], now, lambda _: False)
    assert not state["sources"]["products.coto"]["alerted"]
    advance_state(state, {"products.coto": False}, [], now, lambda _: True)
    assert state["sources"]["products.coto"]["alerted"]


def test_first_run_seeds_offers_then_sends_changed_offer_once_at_night():
    messages = []
    send = lambda message: messages.append(message) or True
    noon = datetime(2026, 11, 4, 12, tzinfo=timezone.utc)
    night = datetime(2026, 11, 5, 0, tzinfo=timezone.utc)  # 21:00 Buenos Aires
    original = offer_record(_offer())
    changed = offer_record(_offer(required_quantity=3, charged_quantity=2))
    state = advance_state({}, {}, [original], noon, send)
    assert not state["pending_offers"]
    advance_state(state, {}, [changed], noon, send)
    assert len(state["pending_offers"]) == 1
    advance_state(state, {}, [changed], night, send)
    advance_state(state, {}, [changed], night, send)
    assert len(messages) == 1
    assert "EAN 7790742358608" in messages[0]
    assert "3x2" in messages[0]
    assert "verificado 2026-11-04" in messages[0]
    assert state["pending_offers"] == {}


def test_restricted_offer_summary_names_store_scope():
    offer = offer_record(_offer(
        applicability_scope="restricted", channel="online", branch_ids=["12"],
        minimum_purchase=5000,
    ))
    summary = offer_summary(offer)
    assert "Canal: online; sucursales: 12; compra minima: $5000.0" in summary


def test_empty_sentinel_catalog_is_a_source_warning_not_a_confirmed_absence():
    from scrapers import SCRAPERS

    async def empty(*args, **kwargs):
        return []

    with patch.object(SCRAPERS["jumbo"], "search_direct", side_effect=empty):
        assert not asyncio.run(_catalog_check("jumbo"))


def test_catalog_without_positive_price_fails_contract():
    from scrapers import SCRAPERS

    async def missing_price(*args, **kwargs):
        return [Product(store="jumbo", name="Leche", price=None, scraped_at="2026-11-04T10:00:00Z")]

    with patch.object(SCRAPERS["jumbo"], "search_direct", side_effect=missing_price):
        assert not asyncio.run(_catalog_check("jumbo"))


def test_fallback_catalog_and_empty_sentinel_are_degraded():
    from datetime import date
    from scrapers import SCRAPERS

    async def empty(*args, **kwargs):
        return []

    fallback = DiscountsResponse(
        date="2026-11-04", stores=["jumbo"], count=1, results=[_offer()],
        warnings=["jumbo: catalogo local sin verificacion actual"],
    )
    with patch.object(source_watch, "STORES", ("jumbo",)), \
            patch.object(SCRAPERS["jumbo"], "search_direct", side_effect=empty), \
            patch.object(source_watch, "scrape_discounts", return_value=fallback):
        observations, offers = source_watch.collect_observations(date(2026, 11, 4))
    assert observations == {"products.jumbo": False, "promotions.jumbo": False}
    assert offers == []


def test_digest_waits_for_current_evidence_and_drops_expired_offers():
    sent = []
    send = lambda message: sent.append(message) or True
    noon = datetime(2026, 11, 4, 12, tzinfo=timezone.utc)
    night = datetime(2026, 11, 6, 0, tzinfo=timezone.utc)
    today_offer = offer_record(_offer())
    expired = offer_record(_offer(id="old", title="Old", end_date="2026-11-04"))
    state = advance_state({}, {}, [], noon, send)
    advance_state(state, {}, [today_offer, expired], noon, send)
    advance_state(state, {}, [], night, send)
    assert not sent
    assert len(state["pending_offers"]) == 1
    advance_state(state, {}, [today_offer], night, send)
    assert len(sent) == 1
    assert "Old" not in sent[0]


def test_test_message_never_checks_sources_or_writes_state(tmp_path):
    state = tmp_path / "watch.json"
    with patch.object(sys, "argv", ["source_watch", "--test-telegram", "--state", str(state)]), \
            patch.object(source_watch, "telegram_send", return_value=True) as send, \
            patch.object(source_watch, "collect_observations") as collect:
        assert source_watch.main() == 0
    assert send.call_count == 1
    collect.assert_not_called()
    assert not state.exists()


def test_dry_run_never_persists_alert_state(tmp_path):
    state = tmp_path / "watch.json"
    with patch.object(sys, "argv", ["source_watch", "--dry-run", "--state", str(state)]), \
            patch.object(source_watch, "collect_observations", return_value=({"products.coto": False}, [])):
        assert source_watch.main() == 1
    assert not state.exists()


def test_telegram_accepts_private_chat_id():
    from io import BytesIO

    response = BytesIO(b'{"ok": true}')
    response.status = 200
    with patch.dict("os.environ", {"TELEGRAM_BOT_TOKEN": "test", "TELEGRAM_CHAT_ID": "123"}), \
            patch.object(source_watch, "urlopen", return_value=response) as open_url:
        assert source_watch.telegram_send("test")
    open_url.assert_called_once()
    assert b'"chat_id": "123"' in open_url.call_args.args[0].data


def test_telegram_rejects_invalid_chat_id_before_network():
    with patch.dict("os.environ", {"TELEGRAM_BOT_TOKEN": "test", "TELEGRAM_CHAT_ID": "0"}), \
            patch.object(source_watch, "urlopen") as open_url:
        assert not source_watch.telegram_send("test")
    open_url.assert_not_called()


def test_discover_private_chat_id_only_prints_ids_not_token(capsys):
    from io import BytesIO

    response = BytesIO(b'{"ok": true, "result": ['
                       b'{"message": {"chat": {"id": 123, "type": "private"}, "text": "/start"}},'
                       b'{"message": {"chat": {"id": -456, "type": "supergroup"}, "text": "/start"}}]}')
    response.status = 200
    with patch.object(source_watch.getpass, "getpass", return_value="secret-token"), \
            patch.object(source_watch, "urlopen", return_value=response):
        assert source_watch.discover_private_chat_id() == 0
    output = capsys.readouterr().out
    assert "123" in output
    assert "-456" not in output
    assert "secret-token" not in output
