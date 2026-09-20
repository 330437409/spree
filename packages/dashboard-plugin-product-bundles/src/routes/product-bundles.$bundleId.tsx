import { useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { productBundlesClient } from '../client'
import { ProductBundleForm } from '../pages/product-bundle-form'
import { toPayload } from './product-bundles.new'

export const Route = createFileRoute('/_authenticated/$storeId/product-bundles/$bundleId')({
  component: EditProductBundleRoute,
})

function EditProductBundleRoute() {
  const { storeId, bundleId } = Route.useParams()
  const navigate = useNavigate()

  const { data: bundle } = useQuery({
    queryKey: ['plugin-product-bundles', 'bundle', bundleId],
    queryFn: () => productBundlesClient.get(bundleId),
  })

  if (!bundle) return null

  return (
    <ProductBundleForm
      bundle={bundle}
      onSubmit={async (values) => {
        await productBundlesClient.update(bundleId, toPayload(values))
        // Back to the list: saving a set is done once it is saved, and the
        // figures it was saved with are what the list renders.
        navigate({ to: '/$storeId/product-bundles', params: { storeId }, replace: true })
      }}
    />
  )
}
