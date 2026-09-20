/**
 * Thin wrapper over the Admin API's product bundles resource.
 *
 * The gem owns the backend and the Admin API serves it, so this is only typed
 * signatures — the panel's hooks and pages consume these, never
 * `adminClient.request` directly, so the endpoints can move in one place.
 */
import type { PaginatedResponse } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import type { ProductBundle, ProductBundleParams } from './types'

export type ProductBundlesListParams = Record<
  string,
  string | number | boolean | (string | number)[] | undefined
>

export const productBundlesClient = {
  list: (params?: ProductBundlesListParams) =>
    adminClient.request<PaginatedResponse<ProductBundle>>('GET', '/product_bundles', { params }),

  get: (id: string) => adminClient.request<ProductBundle>('GET', `/product_bundles/${id}`),

  create: (body: ProductBundleParams) =>
    adminClient.request<ProductBundle>('POST', '/product_bundles', { body }),

  update: (id: string, body: ProductBundleParams) =>
    adminClient.request<ProductBundle>('PATCH', `/product_bundles/${id}`, { body }),

  delete: (id: string) => adminClient.request<void>('DELETE', `/product_bundles/${id}`),
}
