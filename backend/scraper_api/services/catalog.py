from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Iterable

from rapidfuzz import fuzz

from models import Product, SearchMatch

_MEASURE_RE = re.compile(
    r"(?P<value>\d+(?:[.,]\d+)?)\s*(?P<unit>kg|kilos?|grs?|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3|u|un|unid(?:ades)?)\b",
    re.IGNORECASE,
)

_PACK_BEFORE_RE = re.compile(
    r"\b(?P<count>\d{1,2})\s*(?:x|por)\s*(?P<value>\d+(?:[.,]\d+)?)\s*"
    r"(?P<unit>kg|kilos?|grs?|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\b",
    re.IGNORECASE,
)
_PACK_AFTER_RE = re.compile(
    r"\b(?P<value>\d+(?:[.,]\d+)?)\s*"
    r"(?P<unit>kg|kilos?|grs?|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\s*"
    r"(?:x|por)\s*(?P<count>\d{1,2})(?:\s*(?:u|un|unid(?:ades)?))?\b",
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

_MASS_UNITS = {"g": 1.0, "gr": 1.0, "grs": 1.0, "gramo": 1.0, "gramos": 1.0, "kg": 1000.0, "kilo": 1000.0, "kilos": 1000.0}
_VOLUME_UNITS = {"ml": 1.0, "cc": 1.0, "cm3": 1.0, "l": 1000.0, "lt": 1000.0, "lts": 1000.0, "litro": 1000.0, "litros": 1000.0}
_COUNT_UNITS = {"u", "un", "unid", "unidad", "unidades"}

_VARIANT_ALIASES = {
    "milk": {
        "entera": "entera",
        "descremada": "descremada",
        "semidescremada": "semidescremada",
        "liviana": "liviana",
        "liviano": "liviana",
        "light": "liviana",
    },
    "diet": {
        "clasica": "regular",
        "clasico": "regular",
        "original": "regular",
        "regular": "regular",
        "light": "light",
        "liviana": "light",
        "liviano": "light",
        "diet": "light",
        "zero": "zero",
    },
    "sugar": {
        "conazucar": "sugar",
        "sinazucar": "sugar_free",
        "zero": "sugar_free",
    },
    "lactose": {"conlactosa": "lactose", "sinlactosa": "lactose_free", "deslactosada": "lactose_free"},
    "flavor": {
        "original": "original",
        "vainilla": "vainilla",
        "chocolate": "chocolate",
        "frutilla": "frutilla",
        "banana": "banana",
        "coco": "coco",
        "limon": "limon",
        "naranja": "naranja",
    },
    "intensity": {"suave": "suave", "intensa": "intensa", "fuerte": "fuerte"},
    "stems": {"conpalo": "with_stems", "sinpalo": "without_stems"},
    "special": {"protein": "protein", "proteina": "protein", "barista": "barista"},
    "form": {"banada": "coated", "banadas": "coated", "banado": "coated", "rellena": "filled", "rellenas": "filled"},
}

_GENERIC_IDENTITY_TOKENS = {
    "aceite", "agua", "arroz", "azucar", "bebida", "cafe", "clasica", "clasico",
    "combo", "crema", "cracker", "dulce", "entera", "galleta", "galletitas",
    "leche", "light", "liviana", "liviano", "original", "pack", "pan", "queso", "rellena",
    "relleno", "sabor", "sin", "tradicional", "unidad", "unidades", "yerba", "yogur",
    "descremada", "semidescremada", "regular", "diet", "zero", "protein", "proteina",
    "barista", "vainilla", "chocolate", "frutilla", "banana", "coco", "limon", "naranja",
    "con", "palo", "conpalo", "sinpalo", "banada", "banadas", "banado",
    "mas", "sachet", "botella", "carton", "pote", "lata", "caja", "bolsa",
}

_PERCENT_RE = re.compile(r"\b(\d+(?:[.,]\d+)?)\s*%")


@dataclass(frozen=True)
class NormalizedText:
    raw: str
    text: str
    size_value: float | None
    size_unit: str | None
    pack_count: int | None = None
    item_size_value: float | None = None
    percentages: tuple[float, ...] = ()


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


def _pack_measurement(text: str) -> tuple[float | None, str | None, int | None, float | None]:
    stripped = _strip_accents(text).lower()
    match = _PACK_BEFORE_RE.search(stripped) or _PACK_AFTER_RE.search(stripped)
    if not match:
        return None, None, None, None
    try:
        count = int(match.group("count"))
        item_value = float(match.group("value").replace(",", "."))
    except (TypeError, ValueError):
        return None, None, None, None
    multiplier, canonical_unit = _canonical_unit(match.group("unit"))
    if not multiplier or not canonical_unit or count <= 1:
        return None, None, None, None
    canonical_item_value = item_value * multiplier
    return canonical_item_value * count, canonical_unit, count, canonical_item_value


def extract_measurement(text: str) -> tuple[float | None, str | None]:
    pack_total, pack_unit, _, _ = _pack_measurement(text)
    if pack_total is not None:
        return pack_total, pack_unit
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
    percentages = tuple(float(value.replace(",", ".")) for value in _PERCENT_RE.findall(stripped))
    size_value, size_unit = extract_measurement(raw)
    _, _, pack_count, item_size_value = _pack_measurement(raw)
    stripped = _PERCENT_RE.sub(" ", stripped)
    stripped = _MEASURE_RE.sub(" ", stripped)
    stripped = re.sub(r"[^a-z0-9\s]", " ", stripped)
    tokens = [token for token in stripped.split() if token and token not in _STOPWORDS]
    return NormalizedText(
        raw=raw,
        text=" ".join(tokens),
        size_value=size_value,
        size_unit=size_unit,
        pack_count=pack_count,
        item_size_value=item_size_value,
        percentages=percentages,
    )


def search_query_for_product_name(name: str) -> str:
    cleaned = _strip_accents(name or "")
    cleaned = re.sub(r"\b\d+(?:[.,]\d+)?\s*%", " ", cleaned)
    cleaned = re.sub(r"\b\d{8,14}\b", " ", cleaned)
    cleaned = re.sub(
        r"\b(?:oferta|ofertas|promo|promocion|pack|combo|nuevo|nueva)\b",
        " ",
        cleaned,
        flags=re.IGNORECASE,
    )
    return re.sub(r"\s+", " ", cleaned).strip() or (name or "").strip()


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
    score = max(0.0, 100.0 - (difference * 100.0))
    if query.pack_count is not None and candidate.pack_count is not None:
        if query.pack_count != candidate.pack_count:
            return 0.0
        if query.item_size_value and candidate.item_size_value:
            item_largest = max(query.item_size_value, candidate.item_size_value)
            item_difference = abs(query.item_size_value - candidate.item_size_value) / item_largest
            score = min(score, max(0.0, 100.0 - (item_difference * 100.0)))
    elif query.pack_count is not None or candidate.pack_count is not None:
        score = min(score, 72.0)
    return score


def _collapsed_tokens(value: NormalizedText) -> set[str]:
    tokens = set(value.text.split())
    pairs = {f"{left}{right}" for left, right in zip(value.text.split(), value.text.split()[1:])}
    return tokens | pairs


def _variants(value: NormalizedText) -> dict[str, set[str]]:
    tokens = _collapsed_tokens(value)
    return {
        dimension: {canonical for token, canonical in aliases.items() if token in tokens}
        for dimension, aliases in _VARIANT_ALIASES.items()
    }


def _variant_conflict(query: NormalizedText, candidate: NormalizedText) -> bool:
    requested_variants = _variants(query)
    offered_variants = _variants(candidate)
    for dimension, requested in requested_variants.items():
        offered = offered_variants[dimension]
        if requested and offered and requested.isdisjoint(offered):
            return True
    return False


def _missing_requested_variant(query: NormalizedText, candidate: NormalizedText) -> bool:
    requested_variants = _variants(query)
    offered_variants = _variants(candidate)
    missing_variant = any(
        requested and not offered_variants[dimension]
        for dimension, requested in requested_variants.items()
    )
    missing_percentage = bool(query.percentages and not candidate.percentages)
    return missing_variant or missing_percentage


def _has_unrequested_variant(query: NormalizedText, candidate: NormalizedText) -> bool:
    requested_variants = _variants(query)
    offered_variants = _variants(candidate)
    return any(
        offered and not requested_variants[dimension]
        for dimension, offered in offered_variants.items()
    )


def _percentage_conflict(query: NormalizedText, candidate: NormalizedText) -> bool:
    if not query.percentages or not candidate.percentages:
        return False
    return all(abs(requested - offered) > 0.05 for requested in query.percentages for offered in candidate.percentages)


def _identity_tokens(value: NormalizedText) -> set[str]:
    return {
        token
        for token in value.text.split()
        if token not in _GENERIC_IDENTITY_TOKENS and not any(char.isdigit() for char in token)
    }


def _token_is_present(token: str, candidate_tokens: set[str]) -> bool:
    if token in candidate_tokens:
        return True
    if len(token) < 5:
        return False
    return any(len(candidate) >= 5 and fuzz.ratio(token, candidate) >= 88 for candidate in candidate_tokens)


def _identity_matches(query: NormalizedText, candidate: NormalizedText) -> bool:
    requested = _identity_tokens(query)
    if not requested:
        return True
    candidate_tokens = set(candidate.text.split())
    matched = sum(_token_is_present(token, candidate_tokens) for token in requested)
    return matched > 0 and matched / len(requested) >= 0.75


def _size_is_compatible(query: NormalizedText, candidate: NormalizedText) -> bool:
    if query.size_value is None:
        return True
    if candidate.size_value is None or query.size_unit != candidate.size_unit:
        return False
    if query.pack_count != candidate.pack_count and (query.pack_count is not None or candidate.pack_count is not None):
        return False
    return (_size_score(query, candidate) or 0.0) >= 96.0


def _is_eligible_match(query: NormalizedText, candidate: NormalizedText) -> bool:
    if not _size_is_compatible(query, candidate):
        return False
    if _variant_conflict(query, candidate) or _percentage_conflict(query, candidate):
        return False
    if not _identity_matches(query, candidate):
        return False
    query_tokens = set(query.text.split())
    candidate_tokens = set(candidate.text.split())
    return not any(token in _INTENT_TOKENS and token not in candidate_tokens for token in query_tokens)


def products_are_comparable(reference: str, candidate: str) -> bool:
    reference_norm = normalize_text(reference)
    candidate_norm = normalize_text(candidate)
    return _is_eligible_match(reference_norm, candidate_norm) and not _missing_requested_variant(reference_norm, candidate_norm)


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
        if size_score < 90.0:
            score *= 0.45
    if _variant_conflict(query_norm, name_norm) or _percentage_conflict(query_norm, name_norm):
        score *= 0.25
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
        match_type=(
            "similar"
            if _missing_requested_variant(query_norm, name_norm)
            or _has_unrequested_variant(query_norm, name_norm)
            else "exact"
        ),
    )


def rank_search_results(
    query: str,
    rows: Iterable[Product | dict],
    limit: int = 20,
    minimum_score: float = 35.0,
) -> list[SearchMatch]:
    matches: list[SearchMatch] = []
    query_norm = normalize_text(query)
    for row in rows:
        product = _coerce_product(row)
        if not product.name or product.available is False:
            continue
        if product.price is None:
            continue
        name_norm = normalize_text(product.name)
        if not _is_eligible_match(query_norm, name_norm):
            continue
        match = score_product_match(query, product)
        if match.score >= minimum_score:
            matches.append(match)

    matches.sort(
        key=lambda match: (
            match.match_type != "exact",
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
