import { type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { type ProductBundlesListParams, productBundlesClient } from '../client'
import type { ProductBundle } from '../types'

interface ProductBundlesListPageProps {
  /** URL-driven table state (page, sort, search), validated by the route. */
  searchParams: ResourceSearch
}

/**
 * The sets a store sells, as one table.
 *
 * The figures beside each one are the server's — what the components cost one
 * by one, what the set costs, what it saves and how many the shelf can fill —
 * so the operator reads the same numbers a shopper's page renders.
 */
export function ProductBundlesListPage({ searchParams }: ProductBundlesListPageProps) {
  return (
    <ResourceTable<ProductBundle>
      tableKey="product_bundles"
      queryKey="product_bundles"
      queryFn={(params) => productBundlesClient.list(params as ProductBundlesListParams)}
      searchParams={searchParams}
    />
  )
}
