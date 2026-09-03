from typing import Optional

from pydantic import BaseModel, Field

class Product(BaseModel):
    store: str
    name: str
    price: Optional[float] = None
    regular_price: Optional[float] = None
    promo_text: Optional[str] = None
    unit: Optional[str] = None
    url: Optional[str] = None
    image: Optional[str] = None
    available: Optional[bool] = True
    scraped_at: str


class SearchRequest(BaseModel):
    query: str = Field(min_length=2, max_length=200)
    limit: int = Field(default=20, ge=1, le=100)
    stores: Optional[list[str]] = None


class SearchMatch(BaseModel):
    product: Product
    score: float = Field(ge=0, le=100)
    normalized_query: str
    normalized_name: str
    size_match: Optional[float] = None


class SearchResponse(BaseModel):
    query: str
    stores: list[str]
    count: int
    results: list[SearchMatch]


class CartItem(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    quantity: int = Field(default=1, ge=1, le=1000)


class CartItemMatch(BaseModel):
    item: CartItem
    matches: list[SearchMatch]
    chosen: Optional[SearchMatch] = None


class StoreTotal(BaseModel):
    store: str
    total: float
    items_found: int
    items_total: int
    missing_items: int


class CompareRequest(BaseModel):
    items: list[CartItem] = Field(min_length=1)
    limit: int = Field(default=20, ge=1, le=50)
    stores: Optional[list[str]] = None


class CompareResponse(BaseModel):
    items: list[CartItemMatch]
    ranking: list[StoreTotal]
    stores: list[str]
    items_count: int
