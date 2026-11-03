"""Conservative readers for retailer-owned promotion pages."""

from dataclasses import dataclass
from datetime import date, datetime, timezone
from html.parser import HTMLParser
import re

from models import DiscountPromotion


JUMBO_LEGALS_URL = "https://www.jumbo.com.ar/legales"
LAREINA_BENEFITS_URL = "https://www.lareinaweb.com.ar/"

_DATE_RANGE = re.compile(
    r"\bdel\s+(\d{2}/\d{2}/\d{4})\s+al\s+(\d{2}/\d{2}/\d{4})\b", re.I
)
_END_DATE = re.compile(r"\bhasta\s+el\s+(\d{2}/\d{2}/\d{2,4})\b", re.I)


class _PageParagraphs(HTMLParser):
    def __init__(self, html: str):
        super().__init__(convert_charrefs=True)
        self.paragraphs: list[tuple[str, bool]] = []
        self._promo_depth = 0
        self._paragraph_depth = 0
        self._parts: list[str] = []
        self._is_promo = False
        self.feed(html)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        if tag == "div":
            classes = dict(attrs).get("class") or ""
            if self._promo_depth:
                self._promo_depth += 1
            elif "promo-item" in classes.split():
                self._promo_depth = 1
        if tag == "p":
            if not self._paragraph_depth:
                self._parts = []
                self._is_promo = self._promo_depth > 0
            self._paragraph_depth += 1

    def handle_endtag(self, tag: str):
        if tag == "p" and self._paragraph_depth:
            self._paragraph_depth -= 1
            if not self._paragraph_depth:
                text = " ".join(" ".join(self._parts).split())
                if text:
                    self.paragraphs.append((text, self._is_promo))
        if tag == "div" and self._promo_depth:
            self._promo_depth -= 1

    def handle_data(self, data: str):
        if self._paragraph_depth:
            self._parts.append(data)


def _date(value: str) -> date | None:
    try:
        day, month, year = (int(piece) for piece in value.split("/"))
        if year < 100:
            year += 2000
        return date(year, month, day)
    except ValueError:
        return None


def parse_jumbo_legals(html: str, selected_date: date) -> list[DiscountPromotion]:
    rows = []
    for text, _ in _PageParagraphs(html).paragraphs:
        if not re.match(r"\d+\)CYBER JUMBO\b", text, re.I):
            continue
        if "NONFOOD" in text[:40].upper() or "productos seleccionados" not in text.lower():
            continue
        match = _DATE_RANGE.search(text)
        if not match or "hasta 2x1" not in text.lower():
            continue
        start, end = _date(match.group(1)), _date(match.group(2))
        if not start or not end or start > end or not start <= selected_date <= end:
            continue
        rows.append(DiscountPromotion(
            id=f"jumbo-cyber-{start.isoformat()}-{end.isoformat()}",
            store="jumbo",
            title="Cyber Jumbo: productos seleccionados",
            benefit="Hasta 2x1 en productos seleccionados; verificar cada articulo",
            percentage=0,
            weekdays=list(range(1, 8)),
            start_date=start.isoformat(), end_date=end.isoformat(),
            channel="online", categories=["campana_sin_ean"],
            conditions=text, source_url=JUMBO_LEGALS_URL,
            scraped_at=datetime.now(timezone.utc).isoformat(),
            promotion_kind="store_product", source_type="official_page",
            verification_status="source_reported",
            calculation_status="not_calculable",
            applicability_scope="restricted",
        ))
    return rows


@dataclass(frozen=True)
class LaReinaBenefitsAudit:
    parsed_cards: int
    expired: int
    unverifiable: int


def inspect_lareina_benefits(html: str, selected_date: date) -> LaReinaBenefitsAudit:
    cards = [text for text, is_promo in _PageParagraphs(html).paragraphs if is_promo]
    expired = unverifiable = 0
    for text in cards:
        match = _END_DATE.search(text)
        end = _date(match.group(1)) if match else None
        if end and end < selected_date:
            expired += 1
        else:
            # A card without a checked start, channel and complete eligibility
            # must not become a discount simply because its end date is future.
            unverifiable += 1
    return LaReinaBenefitsAudit(len(cards), expired, unverifiable)
