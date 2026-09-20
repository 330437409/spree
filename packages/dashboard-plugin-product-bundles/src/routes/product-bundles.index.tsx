/**
 * The bundles list route — compiled into the host's route tree by
 * `spreeDashboardPlugin()`, which reads the `spree.dashboard.routes` marker in
 * this package's package.json.
 *
 * The path literal is the final composed path: plugin routes mount under the
 * dashboard's `_authenticated/$storeId` layout.
 */
import { resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { ProductBundlesListPage } from '../pages/product-bundles-list'

export const Route = createFileRoute('/_authenticated/$storeId/product-bundles/')({
  validateSearch: resourceSearchSchema,
  component: ProductBundlesRoute,
})

function ProductBundlesRoute() {
  return <ProductBundlesListPage searchParams={Route.useSearch()} />
}
