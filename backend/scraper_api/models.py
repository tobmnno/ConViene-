from typing import Literal, Optional

from pydantic import BaseModel, Field

class QuantityOffer(BaseModel):
    id: str
    mechanic: Literal["buy_n_pay_m", "second_unit_discount"]
    required_quantity: int = Field(ge=2)
    charged_quantity: int = Field(default=1, ge=0)
    second_unit_discount: float = Field(default=0, ge=0, le=100)
    source_url: str
    captured_at: str
    branch_id: str


class Product(BaseModel):
    store: str
    name: str
    ean: Optional[str] = None
    brand: Optional[str] = None
    price: Optional[float] = None
    regular_price: Optional[float] = None
    promo_text: Optional[str] = None
    quantity_offers: list[QuantityOffer] = Field(default_factory=list)
    unit: Optional[str] = None
    url: Optional[str] = None
    image: Optional[str] = None
    available: Optional[bool] = True
    branch_id: Optional[str] = None
    pricing_scope: Optional[str] = None
    delivery_available: Optional[bool] = None
    scraped_at: str


class ShoppingContext(BaseModel):
    postal_code: Optional[str] = Field(default=None, pattern=r"^\d{4}$")
    fulfillment: str = Field(default="pickup", pattern=r"^(pickup|delivery)$")
    coto_store: Optional[str] = Field(default=None, pattern=r"^\d{1,6}$")
    carrefour_sales_channel: Optional[str] = Field(default=None, pattern=r"^\d{1,4}$")
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)


class SearchRequest(BaseModel):
    query: str = Field(min_length=2, max_length=200)
    limit: int = Field(default=20, ge=1, le=100)
    stores: Optional[list[str]] = None
    context: Optional[ShoppingContext] = None


class SearchMatch(BaseModel):
    product: Product
    score: float = Field(ge=0, le=100)
    normalized_query: str
    normalized_name: str
    size_match: Optional[float] = None
    match_type: str = "similar"


class SearchResponse(BaseModel):
    query: str
    stores: list[str]
    count: int
    results: list[SearchMatch]
    context: Optional[ShoppingContext] = None
    store_status: dict[str, str] = Field(default_factory=dict)
    partial: bool = False
    unavailable_products: list[Product] = Field(default_factory=list)
    identified_product: Optional[Product] = None


class ProductReference(BaseModel):
    name: str = Field(min_length=2, max_length=300)
    ean: Optional[str] = Field(default=None, pattern=r"^\d{8,14}$")
    brand: Optional[str] = Field(default=None, max_length=100)


class EquivalentsRequest(BaseModel):
    product: ProductReference
    stores: Optional[list[str]] = None
    context: ShoppingContext = Field(default_factory=ShoppingContext)


class EquivalentsResponse(BaseModel):
    results: list[SearchMatch]
    alternatives: list[SearchMatch] = Field(default_factory=list)
    # not_found means not located in this catalog/context, never proof of absence.
    store_status: dict[str, str]
    checked_at: str


class CartItem(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    ean: Optional[str] = Field(default=None, pattern=r"^\d{8,14}$")
    brand: Optional[str] = Field(default=None, max_length=100)
    quantity: int = Field(default=1, ge=1, le=1000)


class CartItemMatch(BaseModel):
    item: CartItem
    matches: list[SearchMatch]
    chosen: Optional[SearchMatch] = None
    store_status: dict[str, str] = Field(default_factory=dict)


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
    context: ShoppingContext = Field(default_factory=ShoppingContext)


class CompareResponse(BaseModel):
    items: list[CartItemMatch]
    ranking: list[StoreTotal]
    stores: list[str]
    items_count: int


class DiscountPromotion(BaseModel):
    id: str
    store: str
    title: str
    benefit: str = ""
    payment_type: str = "card"
    entity: str = ""
    percentage: float = 0
    refund_cap: float = 0
    minimum_purchase: float = 0
    weekdays: list[int] = Field(default_factory=list)
    start_date: str
    end_date: str
    conditions: str = ""
    categories: list[str] = Field(default_factory=lambda: ["todos"])
    channel: str = ""
    valid_text: str = ""
    source_url: str = ""
    compatible_entities: list[str] = Field(default_factory=list)
    required_entity_groups: list[list[str]] = Field(default_factory=list)
    compatible_payment_types: list[str] = Field(default_factory=list)
    any_entity: bool = False
    scraped_at: str
    promotion_kind: Literal["payment", "store_product"] = "payment"
    mechanic: Literal["percentage", "buy_n_pay_m", "second_unit_discount", "fixed_bundle_price"] = "percentage"
    product_eans: list[str] = Field(default_factory=list)
    branch_ids: list[str] = Field(default_factory=list)
    required_quantity: int = Field(default=1, ge=1)
    charged_quantity: int = Field(default=1, ge=0)
    second_unit_discount: float = Field(default=0, ge=0, le=100)
    bundle_price: float = Field(default=0, ge=0)
    allows_stacking: bool = False
    cap_frequency: str = ""
    source_type: Literal["official_api", "official_page", "third_party_feed", "static_fallback"] = "static_fallback"
    verification_status: Literal["source_reported", "unverified"] = "unverified"
    calculation_status: Literal["exact", "estimate", "not_calculable"] = "not_calculable"


class DiscountsResponse(BaseModel):
    date: str
    stores: list[str]
    count: int
    results: list[DiscountPromotion]
    warnings: list[str] = Field(default_factory=list)
