/**
 * The 套餐 the Admin API answers with: a composition, what it costs and what it
 * saves. The figures are the server's — the panel derives none of them.
 */
export interface ProductBundleComponent {
  id: string
  variant_id: string | null
  product_id: string | null
  name: string | null
  quantity: number
  price: number | null
  goods_amount: number | null
  available: number
  in_stock: boolean
  image_url: string | null
}

export interface ProductBundle {
  id: string
  title: string
  slug: string
  /** The currency every figure below is in. */
  currency: string
  status: 'draft' | 'active' | 'archived'
  position: number
  /** The rule the merchant edits: a fixed amount or a percentage. */
  saving_kind: 'amount' | 'percentage'
  saving_value: number
  goods_price: number
  price: number
  saving: number
  available: number
  seller_id: string | null
  components: ProductBundleComponent[]
  created_at: string
  updated_at: string
  deleted_at: string | null
}

/** What a component is written as: the whole set, flat. */
export interface ProductBundleComponentParams {
  variant_id: string
  quantity: number
}

export interface ProductBundleParams {
  title?: string
  slug?: string
  status?: ProductBundle['status']
  position?: number
  preferred_discount_kind?: 'amount' | 'percentage'
  preferred_discount_value?: number
  components?: ProductBundleComponentParams[]
}
