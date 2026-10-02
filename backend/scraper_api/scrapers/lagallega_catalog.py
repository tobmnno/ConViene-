from html.parser import HTMLParser
import re
from urllib.parse import urljoin

from .base import parse_price

BASE_URL = "https://www.lagallega.com.ar/"


class CatalogPage(HTMLParser):
    """Parse the published product cards, including current and crossed-out prices."""

    def __init__(self, html):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.pages = set()
        self.card = None
        self.div_classes = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        onclick = attrs.get("onclick", "")
        page = re.search(r"productosnl\.asp\?pg=(\d+)", onclick)
        if page:
            self.pages.add(int(page.group(1)))
        if tag == "li" and "cuadProd" in attrs.get("class", "").split():
            self.card = {"name": "", "url": "", "image": "", "ean": None,
                         "izq": "", "izqdes": "", "der": ""}
            self.div_classes = []
        if self.card is None:
            return
        if tag == "div":
            self.div_classes.append(attrs.get("class", ""))
        if tag == "a" and "productosdet.asp" in attrs.get("href", ""):
            self.card["url"] = urljoin(BASE_URL, attrs["href"])
        if tag == "img":
            self.card["image"] = urljoin(BASE_URL, attrs.get("src", ""))
            code = re.match(r"(\d{8,14})\b", attrs.get("alt", ""))
            self.card["ean"] = code.group(1) if code else None

    def handle_data(self, data):
        if self.card is None:
            return
        for class_name in reversed(self.div_classes):
            if class_name == "desc":
                self.card["name"] += data
                break
            if class_name in {"izq", "izqdes", "der"}:
                self.card[class_name] += data
                break

    def handle_endtag(self, tag):
        if self.card is None:
            return
        if tag == "div" and self.div_classes:
            self.div_classes.pop()
        if tag == "li":
            price = parse_price(self.card["der"] or self.card["izq"])
            if self.card["name"].strip() and price is not None and price > 0:
                self.rows.append({
                    "name": self.card["name"].strip(), "price": price,
                    "regular_price": parse_price(self.card["izqdes"]),
                    "ean": self.card["ean"], "image": self.card["image"],
                    "url": self.card["url"],
                })
            self.card = None


def read_catalog_page(session, query, page, headers, timeout):
    response = session.get(urljoin(BASE_URL, "productosnl.asp"),
                           params={"cpoB": query, "TM": "Bus", "pg": page},
                           headers=headers, timeout=timeout)
    if response.status_code != 200:
        return None
    text = response.text
    if "cuadProd" not in text and "No se han encontrado productos" not in text:
        return None
    page = CatalogPage(text)
    if not page.rows and "No se han encontrado productos" not in text:
        return None
    return page
