from __future__ import annotations

from calendar import monthrange
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone
from functools import lru_cache
from html import unescape
import json
from pathlib import Path
import re
import time
from typing import Any

import requests

from models import DiscountPromotion, DiscountsResponse
from scrapers.stores import REQUEST_HEADERS
from services.refresh import refresh_lagallega_catalog
from services.scraper import resolve_stores


COTO_URL = "https://www.coto.com.ar/descuentos"
COTO_PROMOTIONS_URL = (
    "https://www.coto.com.ar/rest/model/atg/actors/cProfileActor/"
    "getPromocionesMulticanal?enviroment=ag"
)
LAGALLEGA_URL = "https://www.lagallega.com.ar/Beneficios.asp"
COINAG_LAGALLEGA_URL = "https://www.bancocoinag.com/Beneficios/beneficio%3D2184"
CARREFOUR_URL = "https://www.carrefour.com.ar/descuentos-bancarios"

CARREFOUR_ENTITY_URL = "https://www.carrefour.com.ar/api/dataentities/{entity}/search"
CARREFOUR_GRAPHQL_URL = "https://www.carrefour.com.ar/_v/private/graphql/v1"
DATA_DIR = Path(__file__).resolve().parents[1] / "data"
STATIC_PROMOTIONS_FILE = DATA_DIR / "promociones-otros-supermercados.json"

MONTHS = {
    "enero": 1,
    "febrero": 2,
    "marzo": 3,
    "abril": 4,
    "mayo": 5,
    "junio": 6,
    "julio": 7,
    "agosto": 8,
    "septiembre": 9,
    "setiembre": 9,
    "octubre": 10,
    "noviembre": 11,
    "diciembre": 12,
}

DAY_FIELDS = {
    "monday": 1,
    "tuesday": 2,
    "wednesday": 3,
    "thursday": 4,
    "friday": 5,
    "saturday": 6,
    "sunday": 7,
}

SPANISH_WEEKDAYS = {
    "lunes": 1,
    "martes": 2,
    "miercoles": 3,
    "miércoles": 3,
    "jueves": 4,
    "viernes": 5,
    "sabado": 6,
    "sábado": 6,
    "domingos": 7,
    "domingo": 7,
}

BANK_ALIASES = {
    "Macro": ["Banco Macro", "Macro", "Macro BMA", "Banco BMA"],
    "Banco Galicia": ["Banco Galicia", "Galicia"],
    "Galicia": ["Banco Galicia", "Galicia"],
    "Patagonia": ["Banco Patagonia", "Patagonia"],
    "Banco_Nacion": ["Banco Nacion", "Banco Nación"],
    "Frances": ["BBVA", "Banco Frances", "Banco Francés"],
    "Superville": ["Banco Supervielle", "Supervielle"],
    "ICBC": ["ICBC"],
    "Bancor": ["Bancor", "Banco Cordoba", "Banco Córdoba"],
}

CARD_ALIASES = {
    "Visa": ["Visa"],
    "Mastercard": ["Mastercard", "Master"],
    "American Express": ["American Express", "Amex"],
    "Cabal": ["Cabal"],
    "Cuenta Digital": ["Cuenta Digital Carrefour", "Cuenta Digital"],
    "Mi Carrefour": ["Mi Carrefour"],
    "Cuenta Dni": ["Cuenta DNI"],
}

_DISCOUNT_CACHE_TTL_SECONDS = 300
_discount_cache: dict[tuple, tuple[float, DiscountsResponse]] = {}


def clear_discount_cache() -> None:
    _discount_cache.clear()


def scrape_discounts(
    stores: list[str] | str | None = None,
    selected_date: date | None = None,
) -> DiscountsResponse:
    current_date = selected_date or date.today()
    selected_stores = resolve_stores(stores)
    cache_key = (tuple(selected_stores), current_date.isoformat())
    cached = _discount_cache.get(cache_key)
    if cached and time.monotonic() - cached[0] < _DISCOUNT_CACHE_TTL_SECONDS:
        return cached[1]
    warnings: list[str] = []
    promotions: list[DiscountPromotion] = []

    def scrape_store(store: str):
        store_warnings: list[str] = []
        try:
            if store == "carrefour":
                rows = _scrape_carrefour(current_date, store_warnings)
                if not rows:
                    static_covered, static_rows = _static_promotions(store, current_date)
                    if static_covered:
                        rows = static_rows
                        store_warnings.append("carrefour: se uso el catalogo local como respaldo")
            elif store == "coto":
                rows = _scrape_coto(current_date, store_warnings)
            else:
                rows = _scrape_lagallega(current_date, store_warnings)
                catalog = refresh_lagallega_catalog()
                catalog_rows = _lagallega_blink_promotions(catalog, current_date)
                if catalog_rows:
                    rows.extend(catalog_rows)
                else:
                    store_warnings.append("la_gallega: el feed automatico no devolvio promociones vigentes")
                static_covered, static_rows = _static_promotions(store, current_date)
                if static_covered:
                    live_entities = {_normalize(row.entity) for row in rows}
                    fallback_rows = [
                        row for row in static_rows if _normalize(row.entity) not in live_entities
                    ]
                    rows.extend(fallback_rows)
                    if fallback_rows:
                        store_warnings.append("la_gallega: promociones cargadas desde el catalogo local")
        except Exception as exc:
            rows = []
            store_warnings.append(f"{store}: no se pudieron leer descuentos ({type(exc).__name__})")
        return rows, store_warnings

    with ThreadPoolExecutor(max_workers=len(selected_stores)) as executor:
        store_results = list(executor.map(scrape_store, selected_stores))
    for rows, store_warnings in store_results:
        promotions.extend(rows)
        warnings.extend(store_warnings)

    promotions = _dedupe(promotions)
    promotions.sort(key=lambda item: (item.store, item.weekdays, item.title))
    response = DiscountsResponse(
        date=current_date.isoformat(),
        stores=selected_stores,
        count=len(promotions),
        results=promotions,
        warnings=warnings,
    )
    _discount_cache[cache_key] = (time.monotonic(), response)
    return response


def _lagallega_blink_promotions(catalog: dict[str, Any], selected_date: date) -> list[DiscountPromotion]:
    benefits = catalog.get("benefits") if isinstance(catalog, dict) else None
    if not isinstance(benefits, list):
        return []
    source_url = _clean_text(catalog.get("source_url")) or LAGALLEGA_URL
    scraped_at = _clean_text(catalog.get("checked_at")) or datetime.now(timezone.utc).isoformat()
    rows: list[DiscountPromotion] = []
    for raw in benefits:
        if not isinstance(raw, dict):
            continue
        conditions = _clean_text(raw.get("condicion"))
        declared_end_date = _parse_iso_date(raw.get("validUntil"))
        end_date = declared_end_date or _extract_end_date(conditions, selected_date.year)
        start_date = _extract_start_date(conditions, selected_date) or date(selected_date.year, 1, 1)
        if end_date is None:
            end_date = date(selected_date.year, 12, 31)
        if (declared_end_date is None and _is_clearly_expired(conditions, selected_date)) or not start_date <= selected_date <= end_date:
            continue
        weekdays = _weekdays_from_text(_clean_text(raw.get("cuando")))
        if not weekdays or selected_date.weekday() + 1 not in weekdays:
            continue

        source_collection = _normalize(_clean_text(raw.get("sourceCollection")))
        entity = "MODO" if "modo" in source_collection else _clean_text(raw.get("bankName")) or "Medio de pago"
        card_name = _clean_text(raw.get("cardName"))
        canonical_card = _canonical_static_entity(card_name) if card_name else ""
        groups = [[entity]]
        if canonical_card and canonical_card not in {"Tarjeta", "Credito", "Debito"}:
            groups.append([canonical_card])
        compatible_entities = _unique([value for group in groups for value in group])
        percentage = _percent_from_text(_clean_text(raw.get("rewardRate")) or _clean_text(raw.get("valor")) or conditions) or 0
        cap = _as_float(raw.get("tope")) or 0
        if not cap:
            caps = raw.get("caps")
            if isinstance(caps, list) and caps and isinstance(caps[0], dict):
                cap = _as_float(caps[0].get("amount")) or 0
        minimum_data = raw.get("minimumPurchaseAmount")
        minimum_purchase = _as_float(minimum_data.get("amount")) if isinstance(minimum_data, dict) else 0
        uses = [_normalize(value) for value in _listify(raw.get("usos"))]
        channel = "Online" if "online" in uses else "Sucursal" if "presencial" in uses else ""
        payment_type = "wallet" if _normalize(entity) in {"modo", "cuenta dni"} else "bank"
        payment_types = [payment_type, "card"] if card_name else [payment_type]
        benefit = _benefit_text(_clean_text(raw.get("benefit")), percentage)
        variant = f" ({card_name})" if card_name and _normalize(entity) == "modo" else ""
        title = f"{entity}{variant} - {benefit}"
        rows.append(
            DiscountPromotion(
                id=f"blink_lagallega_{_slug(str(raw.get('id') or title))}",
                store="la_gallega",
                title=title[:120],
                benefit=benefit,
                payment_type=payment_type,
                entity=entity,
                percentage=percentage,
                refund_cap=cap,
                minimum_purchase=minimum_purchase or 0,
                weekdays=weekdays,
                start_date=start_date.isoformat(),
                end_date=end_date.isoformat(),
                conditions=conditions or _clean_text(raw.get("description")),
                categories=["todos"],
                channel=channel,
                valid_text=_valid_text(start_date, end_date, weekdays),
                source_url=source_url,
                compatible_entities=compatible_entities,
                required_entity_groups=groups,
                compatible_payment_types=payment_types,
                scraped_at=scraped_at,
            )
        )
    return rows


@lru_cache(maxsize=1)
def _static_promotions_payload() -> dict[str, Any]:
    if not STATIC_PROMOTIONS_FILE.exists():
        return {}
    try:
        with STATIC_PROMOTIONS_FILE.open("r", encoding="utf-8-sig") as source:
            payload = json.load(source)
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _static_period(payload: dict[str, Any]) -> tuple[date, date] | None:
    match = re.fullmatch(r"([a-záéíóúñ]+)_(\d{4})", str(payload.get("periodo") or ""), flags=re.I)
    if not match:
        return None
    month = MONTHS.get(match.group(1).lower())
    if month is None:
        return None
    year = int(match.group(2))
    return date(year, month, 1), date(year, month, monthrange(year, month)[1])


def _static_promotions(store: str, selected_date: date) -> tuple[bool, list[DiscountPromotion]]:
    payload = _static_promotions_payload()
    period = _static_period(payload)
    if store not in {"carrefour", "la_gallega"} or period is None:
        return False, []
    period_start, period_end = period

    expected_store = "carrefour" if store == "carrefour" else "la gallega"
    source_rows = (
        payload.get("promociones_la_gallega_actuales")
        if store == "la_gallega" and payload.get("promociones_la_gallega_actuales")
        else payload.get("promociones_otros_supermercados")
    )
    rows: list[DiscountPromotion] = []
    for index, raw in enumerate(source_rows or []):
        if not isinstance(raw, dict) or _normalize(str(raw.get("supermercado") or "")) != expected_store:
            continue
        row = _static_promotion_from_json(
            raw,
            index=index,
            store=store,
            selected_date=selected_date,
            period_start=period_start,
            period_end=period_end,
        )
        if row is not None:
            rows.append(row)
    return True, rows


def _static_promotion_from_json(
    raw: dict[str, Any],
    *,
    index: int,
    store: str,
    selected_date: date,
    period_start: date,
    period_end: date,
) -> DiscountPromotion | None:
    explicit_date = _parse_iso_date(raw.get("fecha_especifica"))
    explicit_start = _parse_iso_date(raw.get("vigencia_desde"))
    explicit_end = _parse_iso_date(raw.get("vigencia_hasta"))
    conditions = _clean_text(raw.get("condiciones"))
    limited_to_capture_period = _static_has_explicit_campaign_period(conditions)
    if explicit_date:
        valid_from = explicit_date
        valid_until = explicit_date
    elif explicit_start or explicit_end:
        valid_from = explicit_start or date(selected_date.year, 1, 1)
        valid_until = explicit_end or date(selected_date.year, 12, 31)
    elif limited_to_capture_period:
        valid_from = period_start
        valid_until = period_end
    else:
        # The JSON period identifies when the data was captured. A promotion without
        # a campaign date remains available by weekday across the selected year.
        valid_from = date(selected_date.year, 1, 1)
        valid_until = date(selected_date.year, 12, 31)
    raw_days = _listify(raw.get("dias"))
    weekdays = list(range(1, 8)) if any(_normalize(day) == "todos" for day in raw_days) else sorted(
        {SPANISH_WEEKDAYS[_normalize(day)] for day in raw_days if _normalize(day) in SPANISH_WEEKDAYS}
    )
    weekdays = weekdays or list(range(1, 8))
    if selected_date < valid_from or selected_date > valid_until or selected_date.weekday() + 1 not in weekdays:
        return None

    benefit_data = raw.get("beneficio") if isinstance(raw.get("beneficio"), dict) else {}
    percentage = _as_float(benefit_data.get("porcentaje")) or 0
    installments = int(_as_float(benefit_data.get("cantidad")) or 0)
    benefit = f"{installments} cuotas sin interes" if installments else _benefit_text("", percentage)

    payment = raw.get("medio_pago") if isinstance(raw.get("medio_pago"), dict) else {}
    entity, entities, required_groups, payment_type, payment_types, any_entity = _static_payment_details(payment)
    minimum_purchase = _as_float(raw.get("compra_minima")) or 0
    if minimum_purchase > 0:
        conditions = _clean_text(f"{conditions} Compra minima: ${minimum_purchase:,.0f}.").replace(",", ".")
    source_url = _clean_text(raw.get("fuente_url")) or (
        CARREFOUR_URL if store == "carrefour" else LAGALLEGA_URL
    )
    channel = "Online" if "online" in _normalize(conditions) else "Sucursal" if "sucursal" in _normalize(conditions) else ""
    captured_at = datetime.fromtimestamp(STATIC_PROMOTIONS_FILE.stat().st_mtime, tz=timezone.utc).isoformat()
    # A wallet offer can require a particular card tier. Keep that tier in the
    # title as well as the compatibility groups so Visa and Mastercard offers
    # do not collapse into one generic promotion during deduplication.
    generic_card_values = {
        "tarjeta",
        "tarjeta fisica",
        "credito",
        "debito",
        "tarjeta credito",
        "tarjeta debito",
    }
    card_variants = [
        value
        for value in _listify(payment.get("tarjeta"))
        if _normalize(value) not in generic_card_values
    ]
    variant_text = " / ".join(_unique(card_variants))
    title = f"{entity} ({variant_text}) - {benefit}" if variant_text else f"{entity} - {benefit}"

    return DiscountPromotion(
        id=f"static_{store}_{index}_{_slug(title)}",
        store=store,
        title=title[:120],
        benefit=benefit,
        payment_type=payment_type,
        entity=entity,
        percentage=percentage,
        refund_cap=_as_float(raw.get("tope_reintegro")) or 0,
        minimum_purchase=minimum_purchase,
        weekdays=weekdays,
        start_date=valid_from.isoformat(),
        end_date=valid_until.isoformat(),
        conditions=conditions,
        categories=["todos"],
        channel=channel,
        valid_text=_valid_text(valid_from, valid_until, weekdays),
        source_url=source_url,
        compatible_entities=entities,
        required_entity_groups=required_groups,
        compatible_payment_types=payment_types,
        any_entity=any_entity,
        scraped_at=captured_at,
    )


def _static_has_explicit_campaign_period(conditions: str) -> bool:
    normalized = _normalize(conditions)
    if re.search(
        r"\b(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\b",
        normalized,
    ):
        return True
    return bool(re.search(r"\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b", normalized))


def _static_payment_details(
    payment: dict[str, Any],
) -> tuple[str, list[str], list[list[str]], str, list[str], bool]:
    raw_type = _clean_text(payment.get("tipo"))
    normalized_type = _normalize(raw_type)
    has_specific_entities = any(
        payment.get(key)
        for key in ("nombre", "banco", "bancos", "billetera", "cliente", "marca", "marcas", "tarjeta")
    )
    any_entity = normalized_type == "todos" and not has_specific_entities
    channel_entities: list[str] = []
    if normalized_type in {"modo", "mercado pago", "cuenta dni", "club la nacion", "mi carrefour", "mi carrefour / anses"}:
        channel_entities.append(raw_type)
    channel_entities.extend(_listify(payment.get("nombre")))
    channel_entities.extend(_listify(payment.get("billetera")))
    channel_entities.extend(_listify(payment.get("cliente")))
    banks = _listify(payment.get("banco")) + _listify(payment.get("bancos"))
    generic_card_values = {
        "tarjeta",
        "tarjeta fisica",
        "credito",
        "debito",
        "tarjeta credito",
        "tarjeta debito",
    }
    card_variants = [
        value
        for value in _listify(payment.get("tarjeta"))
        if _normalize(value) not in generic_card_values
    ]
    brands = _listify(payment.get("marca")) + _listify(payment.get("marcas")) + card_variants
    if "tarjeta" in normalized_type and not banks and not channel_entities:
        channel_entities.append(raw_type)

    raw_groups = [
        _unique([_canonical_static_entity(value) for value in group if _normalize(value) != "cualquier entidad"])
        for group in (channel_entities, banks, brands)
        if any(_normalize(value) != "cualquier entidad" for value in group)
    ]
    required_groups = (
        []
        if any_entity
        else [_unique([entity for group in raw_groups for entity in group])]
        if normalized_type == "todos"
        else raw_groups
    )
    entities = _unique([entity for group in required_groups for entity in group])

    payment_types: list[str] = []
    wallet_tokens = ("modo", "mercado pago", "qr", "billetera", "cuenta digital", "cuenta dni", "mi carrefour", "club la nacion")
    if any(token in normalized_type for token in wallet_tokens) or payment.get("billetera"):
        payment_types.append("wallet")
    if payment.get("banco") or payment.get("bancos"):
        payment_types.append("bank")
    if "tarjeta" in normalized_type or payment.get("tarjeta") or payment.get("marca") or payment.get("marcas"):
        payment_types.append("card")
    if any_entity:
        payment_types = ["card", "bank", "wallet"]
    payment_types = _unique(payment_types) or ["card"]
    entity = "Todos los medios" if any_entity and not entities else (entities[0] if entities else raw_type or "Medios de pago")
    return entity, entities, required_groups, payment_types[0], payment_types, any_entity


def _canonical_static_entity(value: str) -> str:
    normalized = _normalize(value)
    if "visa" in normalized:
        return "Visa"
    if "master" in normalized:
        return "Mastercard"
    aliases = {
        "amex": "American Express",
        "supervielle": "Banco Supervielle",
        "bna+": "Banco Nacion",
        "visa": "Visa",
        "master": "Mastercard",
        "mastercard": "Mastercard",
        "empleado/publico": "Empleado publico",
    }
    return aliases.get(normalized, _clean_text(value))


def _listify(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [_clean_text(item) for item in value if _clean_text(item)]
    cleaned = _clean_text(value)
    return [cleaned] if cleaned else []


def _scrape_carrefour(selected_date: date, warnings: list[str]) -> list[DiscountPromotion]:
    fields = ",".join(
        [
            "id",
            "title",
            "sub_title",
            "discount_percentage",
            "discounts_amount_installments",
            "discounts_text_installments",
            "active",
            "active_from",
            "active_to",
            "valid",
            "market",
            "hyper",
            "ecommerce",
            "express",
            "maxi",
            "legal",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
            "idBank",
            "idCard",
            "order",
        ]
    )
    instant = f"{selected_date.isoformat()}T23:59:59"
    raw_promotions = _master_data(
        "BP",
        fields,
        where=f"active=true AND ((active_from < {instant}) AND (active_to > {instant}))",
    )
    bank_names = _entity_names("FB")
    card_names = _entity_names("FC")
    scraped_at = datetime.now(timezone.utc).isoformat()
    rows: list[DiscountPromotion] = []
    normalized_dates = 0

    for raw in raw_promotions:
        title = _clean_text(raw.get("title"))
        if not title:
            continue
        subtitle = _clean_text(raw.get("sub_title"))
        legal = _clean_text(raw.get("legal"))
        if _is_false(raw.get("valid")):
            continue
        inferred_period = _month_year_period(legal, selected_date.year)
        end_date = _extract_end_date(legal, selected_date.year)
        if not end_date and inferred_period:
            end_date = inferred_period[1]

        start_date = _extract_start_date(legal, selected_date)
        if not start_date and inferred_period:
            start_date = inferred_period[0]
        weekdays = _weekdays_from_flags(raw) or _weekdays_from_text(legal) or list(range(1, 8))
        if selected_date.weekday() + 1 not in weekdays:
            continue
        if (start_date and selected_date < start_date) or (end_date and selected_date > end_date):
            normalized_dates += 1
            continue
        valid_until = end_date or date(selected_date.year, 12, 31)
        valid_from = start_date or date(selected_date.year, selected_date.month, 1)

        percentage = _as_float(raw.get("discount_percentage")) or _percent_from_text(title) or _percent_from_text(legal) or 0
        refund_cap = _cap_from_text(subtitle) or _cap_from_text(legal) or 0
        entity, compatible_entities = _carrefour_entities(
            raw,
            bank_names,
            card_names,
            f"{title} {subtitle}",
        )
        payment_type, payment_types = _payment_type(title, legal, compatible_entities)
        channels = _carrefour_channels(raw)
        benefit = _benefit_text(title, percentage)
        conditions = legal or subtitle

        rows.append(
            DiscountPromotion(
                id=f"carrefour_{raw.get('id')}",
                store="carrefour",
                title=title,
                benefit=benefit,
                payment_type=payment_type,
                entity=entity,
                percentage=percentage,
                refund_cap=refund_cap,
                weekdays=weekdays,
                start_date=valid_from.isoformat(),
                end_date=valid_until.isoformat(),
                conditions=conditions,
                categories=["todos"],
                channel=channels,
                valid_text=_valid_text(valid_from, valid_until, weekdays),
                source_url=CARREFOUR_URL,
                compatible_entities=compatible_entities,
                compatible_payment_types=payment_types,
                any_entity=_is_all_payment_methods(title, legal),
                scraped_at=scraped_at,
            )
        )

    if normalized_dates:
        warnings.append(
            f"carrefour: se omitieron {normalized_dates} promociones marcadas activas cuyos legales estaban vencidos"
        )
    if not rows:
        warnings.append("carrefour: la API oficial no devolvio promociones vigentes para la fecha consultada")
    return rows


def _scrape_coto(selected_date: date, warnings: list[str]) -> list[DiscountPromotion]:
    response = requests.get(COTO_PROMOTIONS_URL, headers=REQUEST_HEADERS, timeout=25)
    response.raise_for_status()
    payload = _response_json(response)
    result = payload.get("result") if isinstance(payload, dict) else None
    if not isinstance(result, dict):
        warnings.append("coto: el endpoint oficial no devolvio el formato esperado")
        return []
    scraped_at = datetime.now(timezone.utc).isoformat()
    rows: list[DiscountPromotion] = []
    for field, channel in (
        ("promocionesDigitales", "Digital"),
        ("promocionesSucursalesFisicas", "Sucursal"),
    ):
        for raw in result.get(field) or []:
            row = _coto_from_api(raw, channel, selected_date, scraped_at)
            if row is not None:
                rows.append(row)
    if not rows:
        warnings.append("coto: el endpoint oficial no devolvio promociones vigentes")
    return rows


def _coto_from_api(raw: dict[str, Any], channel: str, selected_date: date, scraped_at: str):
    discount_text = _clean_text(raw.get("textoDescuento"))
    description = _clean_text(raw.get("descripcion"))
    observation = _clean_text(raw.get("observacion"))
    if not discount_text and not description:
        return None
    combined = _clean_text(f"{discount_text}. {description}. {observation}")
    percentage = _percent_from_text(discount_text) or 0
    weekdays = []
    for raw_day in raw.get("dias") or []:
        try:
            coto_day = int(raw_day.get("id"))
        except (AttributeError, TypeError, ValueError):
            continue
        weekdays.append(7 if coto_day == 1 else coto_day - 1)
    weekdays = sorted(set(weekdays)) or _weekdays_from_text(combined) or list(range(1, 8))
    if selected_date.weekday() + 1 not in weekdays:
        return None
    start_date = _parse_iso_date(raw.get("vigenciaDesde"))
    end_date = _parse_iso_date(raw.get("vigenciaHasta"))
    if (start_date and selected_date < start_date) or (end_date and selected_date > end_date):
        return None
    start_date = start_date or date(selected_date.year, selected_date.month, 1)
    end_date = end_date or date(
        selected_date.year,
        selected_date.month,
        monthrange(selected_date.year, selected_date.month)[1],
    )
    entities = _entities_from_text(f"{description} {observation} {raw.get('icono', '')}")
    payment_type, payment_types = _payment_type(combined, combined, entities)
    title = _clean_text(f"{discount_text} {description}").strip(" .")
    return DiscountPromotion(
        id=f"coto_{channel.lower()}_{raw.get('id') or _slug(title)}",
        store="coto",
        title=title[:120],
        benefit=_benefit_text(discount_text, percentage),
        payment_type=payment_type,
        entity=" y ".join(entities) if entities else "Medios de pago",
        percentage=percentage,
        refund_cap=_cap_from_text(observation) or 0,
        weekdays=weekdays,
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        conditions=observation or description,
        categories=["todos"],
        channel=channel,
        valid_text=_valid_text(start_date, end_date, weekdays),
        source_url=COTO_URL,
        compatible_entities=entities,
        compatible_payment_types=payment_types,
        scraped_at=scraped_at,
    )


def _scrape_lagallega(selected_date: date, warnings: list[str]) -> list[DiscountPromotion]:
    scraped_at = datetime.now(timezone.utc).isoformat()
    with requests.Session() as session:
        page = session.get(LAGALLEGA_URL, headers=REQUEST_HEADERS, timeout=25)
        page.raise_for_status()
        page.encoding = page.apparent_encoding or page.encoding
        payment_methods = _lagallega_payment_methods(page.text)

        rows: list[DiscountPromotion] = []
        for endpoint in ("PromoxDia.asp", "PromoxBanco.asp"):
            url = f"https://www.lagallega.com.ar/{endpoint}"
            response = session.get(url, headers=REQUEST_HEADERS, timeout=25)
            response.encoding = response.apparent_encoding or response.encoding
            text = response.text
            if "top.location.href" in text and "login.asp" in text:
                warnings.append(f"la_gallega: {endpoint} requiere sesion y no publica porcentajes anonimos")
                continue
            rows.extend(_lagallega_promotions_from_html(text, selected_date, scraped_at))

    try:
        rows.extend(_scrape_lagallega_coinag(selected_date, scraped_at))
    except requests.RequestException:
        warnings.append("la_gallega: no se pudo consultar el legal de Banco Coinag")

    if not rows and payment_methods:
        warnings.append(
            "la_gallega: solo se pudieron leer medios de pago aceptados, no descuentos bancarios vigentes"
        )
    return rows


def _scrape_lagallega_coinag(selected_date: date, scraped_at: str) -> list[DiscountPromotion]:
    response = requests.get(COINAG_LAGALLEGA_URL, headers=REQUEST_HEADERS, timeout=25)
    response.raise_for_status()
    response.encoding = response.apparent_encoding or response.encoding
    detail_match = re.search(
        r"<h2[^>]*class=['\"]local['\"][^>]*>\s*Supermercado La Gallega\s*</h2>(.*?)(?=<h3>Tarjetas</h3>)",
        response.text,
        flags=re.I | re.S,
    )
    text = _html_to_text(detail_match.group(1) if detail_match else response.text)
    if "supermercado la gallega" not in _normalize(_html_to_text(response.text)):
        return []

    percentage = _percent_from_text(_html_to_text(response.text))
    end_date = _extract_end_date(text, selected_date.year)
    weekdays = _weekdays_from_text(text)
    if not percentage or not end_date or not weekdays:
        return []
    start_date = _extract_start_date(text, selected_date) or date(selected_date.year, 1, 1)
    if selected_date < start_date or selected_date > end_date or selected_date.weekday() + 1 not in weekdays:
        return []

    entities = ["Banco Coinag", "Visa"]
    return [
        DiscountPromotion(
            id="la_gallega_coinag",
            store="la_gallega",
            title="Banco Coinag - 20% OFF",
            benefit=_benefit_text("", percentage),
            payment_type="bank",
            entity="Banco Coinag",
            percentage=percentage,
            refund_cap=_cap_from_text(text) or 0,
            weekdays=weekdays,
            start_date=start_date.isoformat(),
            end_date=end_date.isoformat(),
            conditions=_clean_text(text),
            categories=["todos"],
            channel="Sucursal",
            valid_text=_valid_text(start_date, end_date, weekdays),
            source_url=COINAG_LAGALLEGA_URL,
            compatible_entities=entities,
            compatible_payment_types=["bank", "card"],
            scraped_at=scraped_at,
        )
    ]


def _master_data(entity: str, fields: str, *, where: str = "") -> list[dict[str, Any]]:
    field_names = [field.strip() for field in fields.split(",") if field.strip()]
    query = """
        query GetDocuments($acronym: String!, $fields: [String!]!, $where: String) {
          documents(
            acronym: $acronym,
            schema: \"mdv1\",
            fields: $fields,
            where: $where,
            sort: \"order ASC\",
            account: \"carrefourar\",
            pageSize: 999
          ) {
            fields { key value }
          }
        }
    """
    response = requests.post(
        CARREFOUR_GRAPHQL_URL,
        json={
            "operationName": "GetDocuments",
            "variables": {"acronym": entity, "fields": field_names, "where": where},
            "query": query,
        },
        headers=REQUEST_HEADERS,
        timeout=25,
    )
    response.raise_for_status()
    payload = _response_json(response)
    documents = payload.get("data", {}).get("documents", []) if isinstance(payload, dict) else []
    rows: list[dict[str, Any]] = []
    for document in documents:
        raw_fields = document.get("fields") if isinstance(document, dict) else None
        if not isinstance(raw_fields, list):
            continue
        rows.append(
            {
                str(field.get("key")): field.get("value")
                for field in raw_fields
                if isinstance(field, dict) and field.get("key")
            }
        )
    return rows


def _entity_names(entity: str) -> dict[str, str]:
    try:
        rows = _master_data(entity, "id,image,name")
    except Exception:
        return {}
    return {
        str(row.get("id")): _clean_text(row.get("name")).replace("_", " ")
        for row in rows
        if row.get("id") and row.get("name")
    }


def _coto_from_text(text: str, selected_date: date, scraped_at: str) -> DiscountPromotion | None:
    percentage = _percent_from_text(text) or 0
    if not percentage and "cuota" not in text.lower():
        return None
    end_date = _extract_end_date(text, selected_date.year) or date(selected_date.year, selected_date.month, 28)
    start_date = _extract_start_date(text, selected_date) or date(selected_date.year, selected_date.month, 1)
    if selected_date < start_date or selected_date > end_date:
        return None
    entities = _entities_from_text(text)
    return DiscountPromotion(
        id=f"coto_{_slug(text[:80])}",
        store="coto",
        title=text[:90],
        benefit=_benefit_text(text, percentage),
        payment_type=_payment_type(text, text, entities)[0],
        entity=" y ".join(entities) if entities else "Medios de pago",
        percentage=percentage,
        refund_cap=_cap_from_text(text) or 0,
        weekdays=_weekdays_from_text(text) or list(range(1, 8)),
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        conditions=text,
        categories=["electro"] if "electro" in _normalize(text) else ["todos"],
        channel="Digital" if "digital" in _normalize(text) else "",
        valid_text=_valid_text(start_date, end_date, _weekdays_from_text(text) or list(range(1, 8))),
        source_url=COTO_URL,
        compatible_entities=entities,
        compatible_payment_types=_payment_type(text, text, entities)[1],
        scraped_at=scraped_at,
    )


def _promotion_chunks(text: str) -> list[str]:
    sentences = re.split(r"(?<=[.!?])\s+", text)
    chunks = []
    for sentence in sentences:
        normalized = _normalize(sentence)
        if any(token in normalized for token in ("descuento", "ahorro", "cuota", "visa", "mastercard")):
            cleaned = _clean_text(sentence)
            if len(cleaned) > 20:
                chunks.append(cleaned)
    return chunks[:30]


def _lagallega_payment_methods(html: str) -> list[str]:
    return [
        _clean_text(match.group(1))
        for match in re.finditer(r'alt="([^"]*(?:Tarjeta|Efectivo|Credito|Debito)[^"]*)"', html, flags=re.I)
    ]


def _lagallega_promotions_from_html(html: str, selected_date: date, scraped_at: str) -> list[DiscountPromotion]:
    text = _html_to_text(html)
    rows = []
    for raw_chunk in _promotion_chunks(text):
        weekdays = _weekdays_from_text(raw_chunk) or list(range(1, 8))
        if selected_date.weekday() + 1 not in weekdays:
            continue
        chunk = _clean_lagallega_chunk(raw_chunk)
        percentage = _percent_from_text(chunk) or 0
        if not percentage:
            continue
        entities = _entities_from_text(chunk)
        payment_type, payment_types = _payment_type(chunk, chunk, entities)
        start_date = date(selected_date.year, selected_date.month, 1)
        end_date = date(
            selected_date.year,
            selected_date.month,
            monthrange(selected_date.year, selected_date.month)[1],
        )
        rows.append(
            DiscountPromotion(
                id=f"la_gallega_{_slug(chunk[:80])}",
                store="la_gallega",
                title=_promotion_title(chunk),
                benefit=_benefit_text(chunk, percentage),
                payment_type=payment_type,
                entity=" y ".join(entities) or "Medios de pago",
                percentage=percentage,
                refund_cap=_cap_from_text(chunk) or 0,
                weekdays=weekdays,
                start_date=start_date.isoformat(),
                end_date=end_date.isoformat(),
                conditions=chunk,
                valid_text=_valid_text(start_date, end_date, weekdays),
                source_url=LAGALLEGA_URL,
                compatible_entities=entities,
                compatible_payment_types=payment_types,
                scraped_at=scraped_at,
            )
        )
    return rows


def _carrefour_entities(
    raw: dict[str, Any],
    bank_names: dict[str, str],
    card_names: dict[str, str],
    title: str,
) -> tuple[str, list[str]]:
    normalized_title = _normalize(title)
    if "cuenta digital de carrefour banco" in normalized_title:
        return "Carrefour Banco", ["Carrefour Banco"]
    if "emplead" in normalized_title and "public" in normalized_title:
        return "Mi Carrefour", ["Mi Carrefour"]
    if "club la nacion" in normalized_title:
        return "Club La Nacion", ["Club La Nacion"]

    title_entities = _entities_from_text(title)
    if title_entities:
        return " y ".join(title_entities), title_entities

    entities: list[str] = []
    bank = bank_names.get(str(raw.get("idBank")))
    card = card_names.get(str(raw.get("idCard")))
    if bank:
        entities.extend(BANK_ALIASES.get(bank, [bank]))
    if card:
        entities.extend(CARD_ALIASES.get(card, [card]))
    entities = _unique(entities)
    return (" y ".join(entities) if entities else "Medios de pago", entities)


def _entities_from_text(text: str) -> list[str]:
    normalized = _normalize(text)
    candidates: list[str] = []
    known = {
        "visa": "Visa",
        "mastercard": "Mastercard",
        "master": "Mastercard",
        "american express": "American Express",
        "amex": "American Express",
        "cabal": "Cabal",
        "macro": "Banco Macro",
        "bma": "Banco Macro",
        "galicia": "Banco Galicia",
        "patagonia": "Banco Patagonia",
        "santa fe": "Banco Santa Fe",
        "coinag": "Banco Coinag",
        "credicoop": "Banco Credicoop",
        "nacion": "Banco Nacion",
        "banco nacion": "Banco Nacion",
        "mercado pago": "Mercado Pago",
        "modo": "MODO",
        "naranja": "Naranja X",
        "cuenta dni": "Cuenta DNI",
        "carrefour banco": "Carrefour Banco",
        "mi carrefour": "Mi Carrefour",
        "club la nacion": "Club La Nacion",
        "comafi": "Banco Comafi",
        "supervielle": "Banco Supervielle",
        "bbva": "BBVA",
        "icbc": "ICBC",
        "banco ciudad": "Banco Ciudad",
        "banco provincia": "Banco Provincia",
        "hipotecario": "Banco Hipotecario",
        "tci": "Tarjeta TCI",
    }
    for token, label in known.items():
        if token in normalized:
            candidates.append(label)
    return _unique(candidates)


def _payment_type(text: str, legal: str, entities: list[str]) -> tuple[str, list[str]]:
    normalized = _normalize(f"{text} {legal} {' '.join(entities)}")
    types: list[str] = []
    if any(token in normalized for token in ("mercado pago", "modo", "cuenta dni", "billetera", "qr")):
        types.append("wallet")
    if any(token in normalized for token in ("banco", "macro", "galicia", "patagonia")):
        types.append("bank")
    if any(token in normalized for token in ("tarjeta", "visa", "mastercard", "master", "american express", "amex", "cabal")):
        types.append("card")
    types = _unique(types) or ["card"]
    return types[0], types


def _carrefour_channels(raw: dict[str, Any]) -> str:
    labels = []
    for field, label in [
        ("ecommerce", "Online"),
        ("market", "Market"),
        ("hyper", "Hiper"),
        ("express", "Express"),
        ("maxi", "Maxi"),
    ]:
        if _is_true(raw.get(field)):
            labels.append(label)
    return " y ".join(labels)


def _weekdays_from_flags(raw: dict[str, Any]) -> list[int]:
    days = [day for field, day in DAY_FIELDS.items() if _is_true(raw.get(field))]
    return sorted(days)


def _weekdays_from_text(text: str) -> list[int]:
    normalized = _normalize(text)
    if "todos los dias" in normalized or "toda la semana" in normalized:
        return list(range(1, 8))
    if "lunes a viernes" in normalized or "lunes al viernes" in normalized:
        return [1, 2, 3, 4, 5]
    if "sabados y domingos" in normalized or "sabado y domingo" in normalized:
        return [6, 7]
    days = [day for name, day in SPANISH_WEEKDAYS.items() if _normalize(name) in normalized]
    return sorted(set(days))


def _extract_start_date(text: str, selected_date: date) -> date | None:
    explicit = re.search(r"(?:desde|del)\s+(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?", text, flags=re.I)
    if explicit:
        return _make_date(explicit.group(1), explicit.group(2), explicit.group(3), selected_date.year)
    month = _month_from_text(text)
    if month:
        return date(selected_date.year, month, 1)
    return None


def _extract_end_date(text: str, default_year: int) -> date | None:
    explicit = re.search(r"(?:hasta|al)\s+el?\s*(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?", text, flags=re.I)
    if explicit:
        return _make_date(explicit.group(1), explicit.group(2), explicit.group(3), default_year)
    month_match = re.search(r"(?:hasta\s+el\s+)?(\d{1,2})\s+de\s+([a-záéíóúñ]+)(?:\s+de\s+(\d{4}))?", text, flags=re.I)
    if month_match and month_match.group(2).lower() in MONTHS:
        return date(int(month_match.group(3) or default_year), MONTHS[month_match.group(2).lower()], int(month_match.group(1)))
    inclusive = re.search(r"(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\s+inclusive", text, flags=re.I)
    if inclusive:
        return _make_date(inclusive.group(1), inclusive.group(2), inclusive.group(3), default_year)
    return None


def _month_year_period(text: str, default_year: int) -> tuple[date, date] | None:
    normalized = _normalize(text)
    for name, month in MONTHS.items():
        pattern = rf"(?:mes\s+de\s+|dias\s+de\s+|d[ií]as\s+de\s+|de\s+)?{name}(?:\s+de\s+(\d{{4}}))?"
        match = re.search(pattern, normalized, flags=re.I)
        if not match:
            continue
        year = int(match.group(1) or default_year)
        last_day = monthrange(year, month)[1]
        return date(year, month, 1), date(year, month, last_day)
    return None


def _is_clearly_expired(text: str, selected_date: date) -> bool:
    years = [int(match.group(0)) for match in re.finditer(r"\b20\d{2}\b", text)]
    if years and max(years) < selected_date.year:
        return True
    explicit_end = _extract_end_date(text, selected_date.year)
    return bool(explicit_end and explicit_end < selected_date)


def _is_false(value: Any) -> bool:
    if isinstance(value, bool):
        return value is False
    return str(value).strip().lower() in {"false", "0", "no"}


def _is_true(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"true", "1", "si", "sí"}


def _clean_lagallega_chunk(chunk: str) -> str:
    chunk = re.sub(r"^-+>\s*", "", chunk).strip()
    chunk = re.sub(
        r"(?i)^todos\s+los\s+d[ií]as\s+(?:domingo|lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|\s)+-+>\s*",
        "",
        chunk,
    )
    chunk = re.sub(r"\s*-+>\s*", " ", chunk)
    chunk = re.sub(r"(?i)\btodos\s+los\s+d[ií]as\s+", "", chunk)
    return _clean_text(chunk)


def _promotion_title(text: str) -> str:
    title = re.split(
        r"\b(?:tope|vigencia|valido|v[aá]lido|del\s+\d{1,2}[/-]\d{1,2}|en\s+1\s+compra)\b",
        text,
        maxsplit=1,
        flags=re.I,
    )[0]
    return _clean_text(title).strip(" .,-")[:90] or text[:90]


def _make_date(day: str, month: str, year: str | None, default_year: int) -> date | None:
    try:
        parsed_year = int(year) if year else default_year
        if parsed_year < 100:
            parsed_year += 2000
        return date(parsed_year, int(month), int(day))
    except ValueError:
        return None


def _parse_iso_date(value: Any) -> date | None:
    if not value:
        return None
    text = str(value).strip()
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except ValueError:
        match = re.search(r"(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})", text)
        return _make_date(match.group(1), match.group(2), match.group(3), date.today().year) if match else None


def _response_json(response: requests.Response) -> Any:
    try:
        return response.json()
    except requests.JSONDecodeError:
        return __import__("json").loads(response.content.decode("utf-8", errors="replace"))


def _month_from_text(text: str) -> int | None:
    normalized = _normalize(text)
    for name, month in MONTHS.items():
        if name in normalized:
            return month
    return None


def _percent_from_text(text: str) -> float | None:
    match = re.search(r"(\d+(?:[,.]\d+)?)\s*%", text)
    return _as_float(match.group(1)) if match else None


def _cap_from_text(text: str) -> float | None:
    match = re.search(r"(?:tope|devoluci[oó]n|reintegro)[^$]{0,60}\$\s*([\d.,]+)", text, flags=re.I)
    if not match:
        match = re.search(r"\$\s*([\d.,]+)\s*(?:por|mensual|de tope)", text, flags=re.I)
    return _as_float(match.group(1)) if match else None


def _as_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    cleaned = str(value).replace(".", "").replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def _benefit_text(title: str, percentage: float) -> str:
    cuotas = re.search(r"(\d+(?:-\d+)?)\s+cuotas?", title, flags=re.I)
    if cuotas:
        return f"{cuotas.group(1)} cuotas"
    if percentage > 0:
        return f"{percentage:g}% OFF"
    return "Beneficio"


def _valid_text(start_date: date, end_date: date, weekdays: list[int]) -> str:
    return f"Del {start_date.strftime('%d/%m/%Y')} al {end_date.strftime('%d/%m/%Y')}"


def _is_all_payment_methods(title: str, legal: str) -> bool:
    return "todos los medios" in _normalize(f"{title} {legal}")


def _html_to_text(html: str) -> str:
    text = re.sub(r"<script\b[^>]*>.*?</script>", " ", html, flags=re.I | re.S)
    text = re.sub(r"<style\b[^>]*>.*?</style>", " ", text, flags=re.I | re.S)
    text = re.sub(r"<[^>]+>", " ", text)
    return _clean_text(text)


def _get_text(url: str) -> str:
    response = requests.get(url, headers=REQUEST_HEADERS, timeout=25)
    response.raise_for_status()
    response.encoding = response.apparent_encoding or response.encoding
    return response.text


def _clean_text(value: Any) -> str:
    if value is None:
        return ""
    text = unescape(str(value))
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _normalize(value: str) -> str:
    return (
        value.lower()
        .replace("á", "a")
        .replace("é", "e")
        .replace("í", "i")
        .replace("ó", "o")
        .replace("ú", "u")
        .replace("ü", "u")
        .replace("ñ", "n")
    )


def _slug(value: str) -> str:
    return re.sub(r"(^-|-$)", "", re.sub(r"[^a-z0-9]+", "-", _normalize(value)))


def _unique(values: list[str]) -> list[str]:
    seen = set()
    result = []
    for value in values:
        clean = _clean_text(value)
        key = _normalize(clean)
        if clean and key not in seen:
            seen.add(key)
            result.append(clean)
    return result


def _dedupe(promotions: list[DiscountPromotion]) -> list[DiscountPromotion]:
    seen = set()
    result = []
    for promotion in promotions:
        key = (promotion.store, _normalize(promotion.title), promotion.entity, tuple(promotion.weekdays))
        if key in seen:
            continue
        seen.add(key)
        result.append(promotion)
    return result
