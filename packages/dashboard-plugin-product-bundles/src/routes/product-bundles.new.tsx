import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { productBundlesClient } from '../client'
import { ProductBundleForm, type ProductBundleFormValues } from '../pages/product-bundle-form'
import type { ProductBundleParams } from '../types'

export const Route = createFileRoute('/_authenticated/$storeId/product-bundles/new')({
  component: NewProductBundleRoute,
})

function NewProductBundleRoute() {
  const { storeId } = Route.useParams()
  const navigate = useNavigate()

  return (
    <ProductBundleForm
      onSubmit={async (values: ProductBundleFormValues) => {
        const bundle = await productBundlesClient.create(toPayload(values))
        // Replace rather than push: the new form is stale the moment it saves,
        // so a back button should not land on it.
        navigate({
          to: '/$storeId/product-bundles/$bundleId',
          params: { storeId, bundleId: bundle.id },
          replace: true,
        })
      }}
    />
  )
}

/** The form's values as the Admin API writes them: the set, flat. */
export function toPayload(values: ProductBundleFormValues): ProductBundleParams {
  return {
    title: values.title,
    status: values.status,
    preferred_discount_kind: values.discount_kind,
    preferred_discount_value: values.discount_value,
    components: values.components.map((component) => ({
      variant_id: component.variantId,
      quantity: component.quantity,
    })),
  }
}
