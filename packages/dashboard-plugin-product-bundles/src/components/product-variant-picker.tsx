import type { PaginatedResponse } from '@spree/admin-sdk'
import { adminClient, ResourceCombobox } from '@spree/dashboard-core'
import {
  Input,
  InputGroup,
  InputGroupAddon,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

/** The goods a component comes from, as the picker needs them. */
interface PickerProduct {
  id: string
  name: string
  variants?: Array<{ id: string; options_text?: string | null; sku?: string | null }>
}

export interface ComponentDraft {
  /** The goods the merchant picked — a handle for the picker, not stored. */
  productId?: string
  productName?: string
  /** The variant the set holds, which is what a bundle stores. */
  variantId: string
  quantity: number
}

interface ProductVariantPickerProps {
  value: ComponentDraft
  onChange: (next: ComponentDraft) => void
}

const PRODUCTS = '/products'

/**
 * One component of a set: the goods, the variant of it the set holds, and how
 * many.
 *
 * What a bundle stores is the variant — that is the offer, with its own price
 * and stock — so the product is the merchant's way in: picking one narrows the
 * next field to its own variants.
 */
export function ProductVariantPicker({ value, onChange }: ProductVariantPickerProps) {
  const { t } = useTranslation()

  // The variants of the picked goods, or of the goods an existing component
  // already belongs to when the form opens on a saved set.
  const { data: product } = useQuery({
    queryKey: ['plugin-product-bundles', 'product', value.productId],
    enabled: Boolean(value.productId),
    staleTime: 5 * 60_000,
    queryFn: () =>
      adminClient.request<PickerProduct>('GET', `${PRODUCTS}/${value.productId}`, {
        params: { expand: 'variants' },
      }),
  })

  const variants = product?.variants ?? []

  return (
    <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_7rem] items-start gap-3">
      <ResourceCombobox<PickerProduct>
        value={value.productId}
        queryKey="plugin-product-bundles-products"
        placeholder={t('admin.product_bundles_plugin.form.product_placeholder')}
        emptyText={t('admin.product_bundles_plugin.form.no_products')}
        getOptionLabel={(product) => product.name}
        search={async (query) => {
          if (!query) return { data: [] }
          return adminClient.request<PaginatedResponse<PickerProduct>>('GET', PRODUCTS, {
            params: { 'q[name_cont]': query, limit: 20 },
          })
        }}
        hydrate={async (ids) => {
          const results = await Promise.all(
            ids.map((id) => adminClient.request<PickerProduct>('GET', `${PRODUCTS}/${id}`)),
          )
          return { data: results }
        }}
        onChange={(id, record) =>
          onChange({
            ...value,
            productId: id,
            productName: record?.name,
            // A different goods means a different variant: the old one is not
            // in this product's list.
            variantId: '',
          })
        }
      />

      <Select
        value={value.variantId}
        onValueChange={(variantId) => onChange({ ...value, variantId: variantId as string })}
        disabled={variants.length === 0}
      >
        <SelectTrigger>
          <SelectValue placeholder={t('admin.product_bundles_plugin.form.variant_placeholder')} />
        </SelectTrigger>
        <SelectContent>
          {variants.map((variant) => (
            <SelectItem key={variant.id} value={variant.id}>
              {variant.options_text || variant.sku || variant.id}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <InputGroup>
        <Input
          type="number"
          min={1}
          value={value.quantity}
          onChange={(event) => onChange({ ...value, quantity: Number(event.target.value) || 1 })}
        />
        <InputGroupAddon align="inline-end">
          {t('admin.product_bundles_plugin.form.quantity_suffix')}
        </InputGroupAddon>
      </InputGroup>
    </div>
  )
}
