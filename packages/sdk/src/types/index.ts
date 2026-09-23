import type { AddressParams, ListParams } from '@spree/sdk-core'
import type { Cart as CartType } from './generated'

// Re-export all generated types (unprefixed: Product, Order, etc.)
export type {
  Address,
  AdministrativeDivision,
  AppliedPromotion,
  Base,
  BundleComponent,
  Cart,
  CartCount,
  CartProductBundle,
  Category,
  Channel,
  Claim,
  ClaimLineItem,
  ClaimReason,
  Collection,
  Company,
  CompanyInvitation,
  CompanyMembership,
  Country,
  CouponHolding,
  CouponPromotion,
  CreditCard,
  Currency,
  Customer,
  CustomerGroup,
  CustomField,
  DataRequest,
  DataRequestEvent,
  Delivery,
  DeliveryMethod,
  DeliveryRate,
  DeliveryZone,
  DeliveryZoneMember,
  DigitalAsset,
  DigitalLink,
  Discount,
  Fee,
  FlashSale,
  FlashSaleItem,
  FlashSaleSlot,
  FlashSaleTicket,
  FreightSummary,
  Fulfillment,
  GiftCard,
  GiftCardBatch,
  Invitation,
  LineItem,
  Locale,
  Market,
  Media,
  MediaEvent,
  MemberCentre,
  Membership,
  MembershipCard,
  MembershipCardSummary,
  MembershipCardTier,
  MembershipCardTransfer,
  MembershipRight,
  MembershipTier,
  NewsletterSubscriber,
  OptionType,
  OptionValue,
  Order,
  OrderGroup,
  PayConfig,
  Payment,
  PaymentMethod,
  PaymentPin,
  PaymentSession,
  PaymentSetupSession,
  PaymentSource,
  PointAccount,
  PointProduct,
  PointProductVipCard,
  PointTransaction,
  Policy,
  Price,
  PriceHistory,
  Product,
  ProductBundle,
  ProductFilterAvailability,
  ProductFilterAvailabilityOption,
  ProductFilterCategory,
  ProductFilterCategoryOption,
  ProductFilterOption,
  ProductFilterOptionValue,
  ProductFilterPriceRange,
  ProductFilterSortOption,
  ProductFilters,
  ProductPublication,
  ProductType,
  Promotion,
  PromotionCandidate,
  Refund,
  Return,
  ReturnLineItem,
  ReturnReason,
  ScenarioOrder,
  ScenarioPaymentSession,
  Seller,
  SellerDecision,
  ShippingLabelEvent,
  Site,
  SiteOperator,
  State,
  StockLocation,
  StockReservation,
  StoreCredit,
  StoreCreditEvent,
  StoreOrderCancellationReason,
  StorePricePreview,
  StorePricePreview as PricePreview,
  StorePricePreviewItem,
  StorePricePreviewItem as PricePreviewItem,
  StoreShare,
  StoreShare as Share,
  TaxIdentifier,
  TaxLine,
  Transfer,
  Variant,
  VerificationCheck,
  Wishlist,
  WishlistItem,
} from './generated'

// Checkout requirement — a single unsatisfied checkout prerequisite
export interface CheckoutRequirement {
  /** Checkout step this requirement belongs to (e.g. "address", "payment") */
  step: string
  /** Field that needs to be satisfied (e.g. "email", "shipping_address") */
  field: string
  /** Human-readable message describing what's needed */
  message: string
}

// Cart warning type — convenience alias for the inline type from the generated Cart
export type CartWarning = CartType['warnings'][number]

// Hand-written domain types
export type {
  AddressParams,
  ErrorResponse,
  ListParams,
  ListResponse,
  LocaleDefaults,
  PaginatedResponse,
  PaginationMeta,
} from '@spree/sdk-core'

// Store auth types
export interface AuthTokens {
  token: string
  refresh_token: string
  user: {
    id: string
    email: string
    first_name: string | null
    last_name: string | null
  }
}

export type {
  EmailPasswordLogin,
  LoginCredentials,
  ProviderLogin,
  RedirectLogin,
} from '@spree/sdk-core'

/**
 * One way a store lets a shopper sign in, as its login page should present it:
 * the password form for `password`, a button for `redirect`.
 */
export interface AuthProvider {
  key: string
  kind: 'password' | 'redirect'
  /** Button label for a redirect provider. */
  label?: string
  /**
   * The provider returns no email, so the shopper is asked for one before the
   * account exists — `completeRegistration` finishes the sign-in.
   */
  requires_email?: boolean
  /** Where to send the browser, with the signed `state` already in it. */
  authorization_url?: string
}

export interface AuthProvidersResponse {
  providers: AuthProvider[]
}

/**
 * A provider authenticated the shopper but returned no email, so nothing was
 * created: the account needs one, and `auth.completeRegistration` supplies it.
 */
export interface RegistrationRequired {
  status: 'registration_required'
  registration_token: string
}

export type LoginResult = AuthTokens | RegistrationRequired

export interface CompleteRegistrationParams {
  registration_token: string
  email: string
  first_name?: string
  last_name?: string
  /** Whether the shopper ticked the store's terms box. */
  terms_of_service?: boolean
}

export interface RequestPasswordResetParams {
  email: string
  redirect_url?: string
}

export interface ResetPasswordParams {
  password: string
  password_confirmation: string
}

export interface RegisterParams {
  email: string
  password: string
  password_confirmation: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>
}

export interface CartSelectionParams {
  /** Whether the named lines are being bought (true) or put back (false) */
  selected: boolean
  /** The prefixed line item IDs this write is about */
  line_item_ids: string[]
}

/**
 * One line a batch writes: what the cart should hold for it after the request.
 * An entry names either the variant to buy or a line of this cart.
 */
export type CartItemsBatchEntry = (
  | { variant_id: string; line_item_id?: never }
  | { line_item_id: string; variant_id?: never }
) & {
  /** The quantity the line should hold (defaults to 1) */
  quantity?: number
  /** Arbitrary key-value metadata for the line */
  metadata?: Record<string, unknown>
}

export interface CartItemsBatchParams {
  items: CartItemsBatchEntry[]
}

export interface ShareParams {
  /** What kind of thing is being shared, in the api_type shorthand the rest of v3 uses */
  target_type: string
  /** Prefixed ID of the thing being shared */
  target_id: string
  /** What the target itself needs — a binding to mint, a team to join */
  context?: Record<string, unknown>
}

export interface PurchaseHistoryParams extends ListParams {
  /** Ordering: 'recent' (default, most recently bought first) or 'frequent' (bought most often first) */
  sort?: 'recent' | 'frequent'
}

export interface PricePreviewParams {
  /** Currency to price in; defaults to the request's own */
  currency?: string
  /** Price the lines this cart holds instead of naming variants */
  cart_id?: string
  /** The warehouse the page is about, when it is about one */
  stock_location_id?: string
  /** What a registered pricing source needs — a flash sale's activity id, for instance */
  context?: Record<string, unknown>
  /** What to price, and how many of each */
  items: Array<{ variant_id: string; quantity?: number }>
}

export interface ProductListParams extends ListParams {
  /** Sort: 'price', '-price', 'best_selling', 'name', '-name', '-available_on', 'available_on' */
  sort?: string
  /** Batch load: the prefixed product IDs to answer with, in one request (at most 100) */
  ids?: string[]
  /** Full-text search across name and SKU */
  search?: string
  /** Filter: name contains */
  name_cont?: string
  /** Filter: price >= value */
  price_gte?: number
  /** Filter: price <= value */
  price_lte?: number
  /** Filter by option value prefix IDs */
  with_option_value_ids?: string[]
  /** Filter: only in-stock products */
  in_stock?: boolean
  /** Filter: only out-of-stock products */
  out_of_stock?: boolean
  /** Filter: products in category (includes descendants) */
  in_category?: string
  /** Filter: products in any of the given categories (includes descendants, OR logic) */
  in_categories?: string[]
  /**
   * Filter: products in a collection (flat — collections have no hierarchy).
   * Prefer `client.collections.products.list()` for a collection listing: it
   * applies the collection's own `sort_order` as the default.
   */
  in_collection?: string
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined
}

export interface CategoryListParams extends ListParams {
  /** Sort order, e.g. 'name', '-created_at' */
  sort?: string
  /** Filter: name contains */
  name_cont?: string
  parent_id_eq?: string | number
  depth_eq?: number
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined
}

export interface CollectionListParams extends ListParams {
  /** Sort order, e.g. 'position', 'name', '-created_at' */
  sort?: string
  /** Filter: name contains */
  name_cont?: string
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined
}

export interface OrderListParams extends ListParams {
  /** Sort order, e.g. 'completed_at desc' */
  sort?: string
  /** Full-text search across number, email, customer name */
  search?: string
  state_eq?: string
  completed_at_gte?: string
  completed_at_lte?: string
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined
}

// Line item input for bulk cart/order operations
export interface LineItemInput {
  /** Prefixed variant ID (e.g., "variant_k5nR8xLq") */
  variant_id: string
  /** Quantity to set (defaults to 1 if omitted) */
  quantity?: number
  /** Arbitrary key-value metadata (merged with existing on upsert) */
  metadata?: Record<string, unknown>
}

// Cart operations
export interface CreateCartParams {
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>
  /** Items to add to the cart on creation */
  items?: LineItemInput[]
}

export interface AddLineItemParams {
  variant_id: string
  quantity: number
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>
}

export interface UpdateLineItemParams {
  quantity?: number
  /** Arbitrary key-value metadata (merged with existing) */
  metadata?: Record<string, unknown>
}

export interface UpdateCartParams {
  email?: string
  currency?: string
  locale?: string
  customer_note?: string
  /** Arbitrary key-value metadata (merged with existing) */
  metadata?: Record<string, unknown>
  /** Existing address ID to use as billing address */
  billing_address_id?: string
  /** Existing address ID to use as shipping address */
  shipping_address_id?: string
  /** New billing address */
  billing_address?: AddressParams
  /** New shipping address */
  shipping_address?: AddressParams
  /** When true, copies shipping address to billing address */
  use_shipping?: boolean
  /** Items to upsert (sets quantity for existing, creates new) */
  items?: LineItemInput[]
  /**
   * The company node this purchase is for. The buyer must have standing over
   * it — a membership on that node or one of its ancestors. Null clears it,
   * and with it the company's catalog, pricing and tax anchoring.
   */
  company_id?: string | null
  /**
   * The buyer's own purchase-order reference. Their accounting reconciles the
   * order, the invoice and the payment against it. Blank clears it.
   */
  po_number?: string | null
  /**
   * ActiveStorage signed blob id of the buyer's purchase order, from
   * `POST /store/carts/:id/po_document`. Blank detaches the document.
   */
  po_document?: string | null
}

// Payments
export interface CreatePaymentParams {
  payment_method_id: string
  amount?: string
  metadata?: Record<string, unknown>
}

// Payment Sessions
export interface CreatePaymentSessionParams {
  payment_method_id: string
  amount?: string
  external_data?: Record<string, unknown>
}

export interface UpdatePaymentSessionParams {
  amount?: string
  external_data?: Record<string, unknown>
}

export interface CompletePaymentSessionParams {
  session_result?: string
  external_data?: Record<string, unknown>
}

// Payment Setup Sessions
export interface CreatePaymentSetupSessionParams {
  payment_method_id: string
  external_data?: Record<string, unknown>
}

export interface CompletePaymentSetupSessionParams {
  external_data?: Record<string, unknown>
}

// Product Filters types
export interface FilterOption {
  id: string
  count: number
}

export interface OptionFilterOption extends FilterOption {
  name: string
  label: string
  position: number
  color_code: string | null
  image_url: string | null
}

export interface CategoryFilterOption {
  id: string
  name: string
  permalink: string
  count: number
}

export interface PriceRangeFilter {
  id: 'price'
  type: 'price_range'
  min: number
  max: number
  currency: string
}

export interface AvailabilityFilter {
  id: 'availability'
  type: 'availability'
  options: FilterOption[]
}

export interface OptionFilter {
  id: string
  type: 'option'
  name: string
  label: string
  kind: string
  options: OptionFilterOption[]
}

export interface CategoryFilter {
  id: 'categories'
  type: 'category'
  options: CategoryFilterOption[]
}

export type ProductFilter = PriceRangeFilter | AvailabilityFilter | OptionFilter | CategoryFilter

export interface SortOption {
  id: string
}

export interface ProductFiltersResponse {
  filters: ProductFilter[]
  sort_options: SortOption[]
  default_sort: string
  total_count: number
}

export interface ProductFiltersParams {
  category_id?: string
  q?: Record<string, unknown>
}

/**
 * An address book entry for a company node: address fields, plus the two
 * things only a book entry has — what it is filed under, and which defaults
 * it holds for its node.
 */
export type CompanyAddressParams = AddressParams & {
  label?: string
  default_billing?: boolean
  default_shipping?: boolean
}

// Named enums — open string unions for lists an extension may extend (statuses, fee kinds)
export type * from './generated/Enums'
