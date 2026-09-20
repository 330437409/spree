import { type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { Button, useRowClickBridge } from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
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
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const navigate = useNavigate()

  // The table's rows carry an id the bridge turns into a click-through to the
  // editor, the way core's own list pages do.
  useRowClickBridge('data-product-bundle-id', (id: string) =>
    navigate({
      to: '/$storeId/product-bundles/$bundleId',
      params: { storeId, bundleId: id },
    }),
  )

  return (
    <ResourceTable<ProductBundle>
      tableKey="product_bundles"
      queryKey="product_bundles"
      queryFn={(params) => productBundlesClient.list(params as ProductBundlesListParams)}
      searchParams={searchParams}
      actions={
        <Button
          size="sm"
          onClick={() => navigate({ to: '/$storeId/product-bundles/new', params: { storeId } })}
        >
          <PlusIcon className="size-4" />
          {t('admin.product_bundles_plugin.page.new_cta')}
        </Button>
      }
    />
  )
}
