"""Low-volume source checks and best-effort Telegram notifications.

Run from backend/scraper_api so the production parsers are importable. This
checks public catalog/benefit sources, not a locally running API instance.
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import date, datetime, timedelta, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
from typing import Callable
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from models import DiscountPromotion
from scrapers import SCRAPERS
from services.catalog import valid_gtin
from services.discounts import scrape_discounts


STORES = ("coto", "carrefour", "la_gallega", "jumbo", "lareina")
OFFICIAL_HOSTS = {
    "coto": "coto.com.ar",
    "carrefour": "carrefour.com.ar",
    "la_gallega": "lagallega.com.ar",
    "jumbo": "jumbo.com.ar",
    "lareina": "lareinaonline.com.ar",
}
ERROR_WARNINGS = ("no se pudieron", "estructura", "sin respuesta", "catalogo local")


def _buenos_aires_timezone():
    try:
        return ZoneInfo("America/Argentina/Buenos_Aires")
    except ZoneInfoNotFoundError:
        # Some Windows Python installations lack the optional IANA tzdata.
        return timezone(timedelta(hours=-3))


def confirmed_product_offer(row: DiscountPromotion, today: date) -> bool:
    """Only announce offers the existing price engine could safely consider."""
    host = (urlparse(row.source_url).hostname or "").lower()
    official = OFFICIAL_HOSTS.get(row.store, "")
    if not official or not (host == official or host.endswith("." + official)):
        return False
    if urlparse(row.source_url).scheme != "https":
        return False
    try:
        active = date.fromisoformat(row.start_date) <= today <= date.fromisoformat(row.end_date)
    except ValueError:
        return False
    scoped = row.applicability_scope == "general_confirmed" or (
        row.applicability_scope == "restricted" and bool(row.branch_ids) and bool(row.channel)
    )
    mechanic_valid = {
        "percentage": 0 < row.percentage <= 100,
        "buy_n_pay_m": row.required_quantity >= 2 and 0 < row.charged_quantity < row.required_quantity,
        "second_unit_discount": row.required_quantity == 2 and 0 < row.second_unit_discount <= 100,
        "fixed_bundle_price": row.required_quantity >= 2 and row.bundle_price > 0,
    }.get(row.mechanic, False)
    return (
        active and scoped and row.promotion_kind == "store_product"
        and row.source_type in {"official_api", "official_page"}
        and row.verification_status == "source_reported"
        and row.calculation_status == "exact"
        and bool(row.product_eans)
        and all(valid_gtin(ean) is not None for ean in row.product_eans)
        and today.isoweekday() in row.weekdays and mechanic_valid
    )


def offer_record(row: DiscountPromotion) -> dict[str, str]:
    fields = {
        "store": row.store,
        "title": row.title,
        "eans": ",".join(sorted(row.product_eans)),
        "mechanic": row.mechanic,
        "quantity": str(row.required_quantity),
        "charged": str(row.charged_quantity),
        "percentage": str(row.percentage),
        "second_unit_discount": str(row.second_unit_discount),
        "bundle_price": str(row.bundle_price),
        "minimum_purchase": str(row.minimum_purchase),
        "refund_cap": str(row.refund_cap),
        "conditions": row.conditions,
        "allows_stacking": str(row.allows_stacking),
        "payment_type": row.payment_type,
        "entity": row.entity,
        "required_entity_groups": json.dumps(row.required_entity_groups, sort_keys=True),
        "channel": row.channel,
        "branches": ",".join(sorted(row.branch_ids)),
        "valid_from": row.start_date,
        "valid_until": row.end_date,
        "source": row.source_url,
    }
    fields["fingerprint"] = hashlib.sha256(
        json.dumps(fields, sort_keys=True).encode("utf-8")
    ).hexdigest()
    fields["captured_at"] = row.scraped_at
    return fields


def offer_summary(offer: dict[str, str]) -> str:
    mechanic = offer["mechanic"]
    if mechanic == "buy_n_pay_m":
        rule = f"{offer['quantity']}x{offer['charged']}"
    elif mechanic == "second_unit_discount":
        rule = f"2da unidad {offer['second_unit_discount']}% off"
    elif mechanic == "fixed_bundle_price":
        rule = f"{offer['quantity']} unidades por ${offer['bundle_price']}"
    else:
        rule = f"{offer['percentage']}% off"
    scope = f"Canal: {offer['channel'] or 'general'}"
    if offer["branches"]:
        scope += f"; sucursales: {offer['branches']}"
    if offer["minimum_purchase"] != "0":
        scope += f"; compra minima: ${offer['minimum_purchase']}"
    return (
        f"{offer['store']}: {offer['title']} | EAN {offer['eans']} | {rule} | "
        f"{scope} | hasta {offer['valid_until']} | verificado {offer['captured_at']} | "
        f"{offer['source']}"
    )


async def _catalog_check(store: str) -> bool:
    # One low-volume direct query per chain; no browser fallback or checkout.
    rows = await asyncio.wait_for(SCRAPERS[store].search_direct("leche", 2), timeout=20)
    return any(row.name.strip() and row.price is not None and row.price > 0 for row in rows or [])


def collect_observations(today: date) -> tuple[dict[str, bool], list[dict[str, str]]]:
    observations: dict[str, bool] = {}
    verified: list[dict[str, str]] = []
    for store in STORES:
        try:
            observations[f"products.{store}"] = asyncio.run(_catalog_check(store))
        except Exception:
            observations[f"products.{store}"] = False
        try:
            response = scrape_discounts([store], today)
            observations[f"promotions.{store}"] = not any(
                phrase in warning.casefold()
                for warning in response.warnings for phrase in ERROR_WARNINGS
            )
            if observations[f"promotions.{store}"]:
                verified.extend(
                    offer_record(row) for row in response.results
                    if confirmed_product_offer(row, today)
                )
        except Exception:
            observations[f"promotions.{store}"] = False
    return observations, verified


def advance_state(
    state: dict, observations: dict[str, bool], offers: list[dict[str, str]],
    now: datetime, send: Callable[[str], bool],
) -> dict:
    """Advance state only after a Telegram delivery succeeds."""
    sources = state.setdefault("sources", {})
    for source, healthy in sorted(observations.items()):
        previous = sources.setdefault(source, {"failures": 0, "alerted": False})
        if healthy:
            if previous["alerted"] and send(f"ConViene: {source} volvió a responder."):
                previous["alerted"] = False
            previous["failures"] = 0
        else:
            previous["failures"] += 1
            if previous["failures"] >= 2 and not previous["alerted"]:
                if send(f"ConViene: {source} no superó {previous['failures']} controles consecutivos (error o consulta de control vacía). Revisar la fuente oficial."):
                    previous["alerted"] = True

    seen = state.setdefault("seen_offers", {})
    pending = state.setdefault("pending_offers", {})
    first_run = not state.get("initialized", False)
    for offer in offers:
        key = f"{offer['store']}:{offer['eans']}:{offer['title']}"
        if seen.get(key) != offer["fingerprint"]:
            if not first_run:
                pending[key] = offer
            seen[key] = offer["fingerprint"]
    state["initialized"] = True

    local_now = now.astimezone(_buenos_aires_timezone())
    day = local_now.date().isoformat()
    active_keys = {
        f"{offer['store']}:{offer['eans']}:{offer['title']}" for offer in offers
    }
    for key, offer in list(pending.items()):
        if offer["valid_until"] < day:
            pending.pop(key)
    digest_keys = [key for key in pending if key in active_keys]
    if digest_keys and local_now.hour >= 20 and state.get("last_digest_day") != day:
        lines = ["ConViene: promociones por producto verificadas (muestreo de fuentes)."]
        included = 0
        for key in digest_keys:
            line = offer_summary(pending[key])
            if included >= 12 or sum(len(part) for part in lines) + len(line) > 3400:
                break
            lines.append(line)
            included += 1
        if len(digest_keys) > included:
            lines.append(f"Y {len(digest_keys) - included} más; revisar el monitor.")
        if send("\n".join(lines)):
            state["last_digest_day"] = day
            for key in digest_keys:
                pending.pop(key)
    state["last_checked_at"] = now.isoformat()
    return state


def telegram_send(message: str) -> bool:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "")
    if not token or not re.fullmatch(r"-?[1-9]\d*", chat_id):
        return False
    payload = json.dumps({"chat_id": chat_id, "text": message[:3900]}).encode("utf-8")
    request = Request(
        f"https://api.telegram.org/bot{token}/sendMessage", data=payload,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    try:
        with urlopen(request, timeout=15) as response:
            return response.status == 200 and json.load(response).get("ok") is True
    except Exception:
        # Exception strings may include the token-bearing request URL.
        print("Telegram delivery failed; will retry on the next run.")
        return False


def discover_private_chat_id() -> int:
    """Read a recent /start without persisting or displaying the bot token."""
    token = getpass.getpass("Telegram bot token (hidden): ").strip()
    if not token:
        print("A bot token is required.")
        return 2
    request = Request(f"https://api.telegram.org/bot{token}/getUpdates?limit=100&timeout=0")
    try:
        with urlopen(request, timeout=15) as response:
            payload = json.load(response)
        if response.status != 200 or payload.get("ok") is not True:
            print("Could not read bot updates. Check the bot token and webhook configuration.")
            return 1
        chat_ids = {
            str(chat["id"])
            for update in payload.get("result", [])
            for message in [update.get("message", {})]
            for chat in [message.get("chat", {})]
            if chat.get("type") == "private"
            and message.get("text", "").startswith("/start")
            and isinstance(chat.get("id"), int)
        }
        if not chat_ids:
            print("No recent private /start found. Open your bot and press Start, then retry.")
            return 1
        print("Private chat ID(s): " + ", ".join(sorted(chat_ids)))
        return 0
    except Exception:
        # URL and HTTP exceptions can contain the bot token.
        print("Could not read bot updates. Check the bot token and webhook configuration.")
        return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", type=Path, default=Path(".source-watch-state.json"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--test-telegram", action="store_true")
    parser.add_argument("--discover-chat-id", action="store_true")
    args = parser.parse_args()
    if args.discover_chat_id:
        return discover_private_chat_id()
    if args.test_telegram:
        if not (os.environ.get("TELEGRAM_BOT_TOKEN") and os.environ.get("TELEGRAM_CHAT_ID")):
            print("Telegram secrets are not configured for this workflow.")
            return 2
        return 0 if telegram_send("ConViene: mensaje de prueba del monitor de fuentes.") else 1
    if not args.dry_run and not (os.environ.get("TELEGRAM_BOT_TOKEN") and os.environ.get("TELEGRAM_CHAT_ID")):
        print("Telegram secrets are not configured.")
        return 2
    try:
        state = json.loads(args.state.read_text(encoding="utf-8"))
    except (FileNotFoundError, ValueError):
        state = {}
    now = datetime.now(_buenos_aires_timezone())
    observations, offers = collect_observations(now.date())
    send = (lambda message: print(message) or True) if args.dry_run else telegram_send
    advance_state(state, observations, offers, now, send)
    if not args.dry_run:
        args.state.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.state.with_suffix(args.state.suffix + ".tmp")
        temporary.write_text(json.dumps(state, ensure_ascii=False, sort_keys=True), encoding="utf-8")
        temporary.replace(args.state)
    print(json.dumps({"sources": observations, "verified_offer_count": len(offers)}, sort_keys=True))
    return 0 if all(observations.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
