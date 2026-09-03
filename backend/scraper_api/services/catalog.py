from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Iterable

from rapidfuzz import fuzz

from models import Product, SearchMatch

_MEASURE_RE = re.compile(
    r"(?P<value>\d+(?:[.,]\d+)?)\s*(?P<unit>kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3|u|un|unid(?:ades)?)\b",
    re.IGNORECASE,
)

_STOPWORDS = {
    "marca",
    "oferta",
    "ofertas",
    "promo",
    "promocion",
    "promoción",
    "pack",
    "combo",
    "nuevo",
    "nueva",
    "tradicional",
    "familiar",
    "x",
    "de",
    "del",
    "la",
    "las",
    "el",
    "los",
    "aprox",
    "aproximadamente",
}

_INTENT_TOKENS = {
    "aceite",
    "agua",
    "arroz",
    "atun",
    "azucar",
    "cafe",
    "carne",
    "cerveza",
    "descremada",
    "dulce",
    "entera",
    "fideos",
    "galletitas",
    "harina",
    "jabon",
    "leche",
    "manteca",
    "mayonesa",
    "pan",
    "papel",
    "pollo",
    "queso",
    "shampoo",
    "tomate",
    "yerba",
    "yogur",
}

_MASS_UNITS = {"g": 1.0, "gr": 1.0, "gramo": 1.0, "gramos": 1.0, "kg": 1000.0, "kilo": 1000.0, "kilos": 1000.0}
_VOLUME_UNITS = {"ml": 1.0, "cc": 1.0, "cm3": 1.0, "l": 1000.0, "lt": 1000.0, "lts": 1000.0, "litro": 1000.0, "litros": 1000.0}
_COUNT_UNITS = {"u", "un", "unid", "unidad", "unidades"}


@dataclass(frozen=True)
class NormalizedText:
    raw: str
    text: str
    size_value: float | None
    size_unit: str | None


def _strip_accents(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(char for char in normalized if not unicodedata.combining(char))


def _canonical_unit(raw_unit: str) -> tuple[float | None, str | None]:
    unit = raw_unit.lower()
    if unit in _MASS_UNITS:
        return _MASS_UNITS[unit], "g"
    if unit in _VOLUME_UNITS:
        return _VOLUME_UNITS[unit], "ml"
    if unit in _COUNT_UNITS:
        return 1.0, "unit"
    return None, None


def extract_measurement(text: str) -> tuple[float | None, str | None]:
    match = _MEASURE_RE.search(_strip_accents(text).lower())
    if not match:
        return None, None
    raw_value = match.group("value").replace(",", ".")
    try:
        numeric_value = float(raw_value)
    except ValueError:
        return None, None
    multiplier, canonical_unit = _canonical_unit(match.group("unit"))
    if multiplier is None or canonical_unit is None:
        return None, None
    return numeric_value * multiplier, canonical_unit


def normalize_text(text: str) -> NormalizedText:
    raw = (text or "").strip()
    stripped = _strip_accents(raw).lower()
    size_value, size_unit = extract_measurement(raw)
    stripped = _MEASURE_RE.sub(" ", stripped)
    stripped = re.sub(r"[^a-z0-9\s]", " ", stripped)
    tokens = [token for token in stripped.split() if token and token not in _STOPWORDS]
    return NormalizedText(raw=raw, text=" ".join(tokens), size_value=size_value, size_unit=size_unit)


def _coerce_product(row: Product | dict) -> Product:
    if isinstance(row, Product):
        return row
    return Product.model_validate(row)


def _size_score(query: NormalizedText, candidate: NormalizedText) -> float | None:
    if query.size_value is None:
        return None
    if candidate.size_value is None:
        return 55.0
    if query.size_unit != candidate.size_unit:
        return 0.0
    largest = max(query.size_value, candidate.size_value)
    if largest <= 0:
        return 0.0
    difference = abs(query.size_value - candidate.size_value) / largest
    return max(0.0, 100.0 - (difference * 100.0))


def score_product_match(query: str, product: Product | dict) -> SearchMatch:
    item = _coerce_product(product)
    query_norm = normalize_text(query)
    name_norm = normalize_text(item.name)
    query_tokens = query_norm.text.split()
    name_tokens = name_norm.text.split()
    matched_tokens = [token for token in query_tokens if token in name_tokens]
    coverage = len(matched_tokens) / len(query_tokens) if query_tokens else 0.0
    density = len(matched_tokens) / len(name_tokens) if name_tokens else 0.0

    base_text_score = max(
        fuzz.WRatio(query_norm.text, name_norm.text),
        fuzz.token_sort_ratio(query_norm.text, name_norm.text),
    )
    text_score = base_text_score * (0.70 + (0.30 * density)) + (coverage * 15.0)
    if name_tokens and query_tokens and name_tokens[0] in query_tokens:
        text_score += 12.0
    if query_norm.text and name_norm.text.startswith(query_norm.text):
        text_score += 8.0
    if coverage < 1.0:
        text_score *= 0.55 + (0.45 * coverage)
    if any(token in _INTENT_TOKENS and token not in name_tokens for token in query_tokens):
        text_score *= 0.35

    size_score = _size_score(query_norm, name_norm)
    score = float(text_score)
    if size_score is not None:
        score = (text_score * 0.82) + (size_score * 0.18)
    if query_norm.text and query_norm.text == name_norm.text:
        score += 5.0
    elif query_norm.text and query_norm.text in name_norm.text:
        score += 3.0

    return SearchMatch(
        product=item,
        score=round(min(score, 100.0), 2),
        normalized_query=query_norm.text,
        normalized_name=name_norm.text,
        size_match=round(size_score, 2) if size_score is not None else None,
    )


def rank_search_results(
    query: str,
    rows: Iterable[Product | dict],
    limit: int = 20,
    minimum_score: float = 35.0,
) -> list[SearchMatch]:
    matches: list[SearchMatch] = []
    for row in rows:
        product = _coerce_product(row)
        if not product.name or product.available is False:
            continue
        if product.price is None:
            continue
        match = score_product_match(query, product)
        if match.score >= minimum_score:
            matches.append(match)

    matches.sort(
        key=lambda match: (
            -match.score,
            match.product.price if match.product.price is not None else float("inf"),
            match.product.store,
            match.product.name.lower(),
        )
    )
    return matches[:limit]


def sort_results_for_output(rows: Iterable[Product | dict]):
    normalized = []
    for row in rows:
        item = row.model_dump() if hasattr(row, "model_dump") else dict(row)
        price = item.get("price")
        try:
            price_value = float(price) if price is not None and str(price).strip() != "" else None
        except (TypeError, ValueError):
            price_value = None
        item["price"] = price_value
        normalized.append(
            (
                price_value is None,
                price_value if price_value is not None else float("inf"),
                (item.get("name") or "").lower(),
                item,
            )
        )

    normalized.sort(key=lambda x: (x[0], x[1], x[2]))
    return [item for _, _, _, item in normalized]
