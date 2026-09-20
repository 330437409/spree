/**
 * @spree/dashboard-plugin-product-bundles — 套餐.
 *
 * The panel half of `spree_product_bundles`: the operator sees the sets their
 * store sells, what each one costs against its components' own prices, and
 * what it saves. The bundle's figures are the server's — this plugin derives
 * none of them — and its composition is edited as the whole set, because that
 * is what the Admin API writes.
 *
 * A real plugin ships a Rails-side resource with it — the gem's controllers,
 * models and Admin API resource live in the `spree_product_bundles` extension.
 */
import { defineDashboardPlugin, defineTable, i18n } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import { formatAmount } from './format'
import en from './locales/en.json'
import zhCN from './locales/zh-CN.json'
import type { ProductBundle } from './types'

i18n.addResourceBundle('en', 'translation', en, true, true)
i18n.addResourceBundle('zh-CN', 'translation', zhCN, true, true)

defineTable<ProductBundle>('product_bundles', {
  title: i18n.t('admin.product_bundles_plugin.table.title'),
  searchParam: 'search',
  searchPlaceholder: i18n.t('admin.product_bundles_plugin.table.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyMessage: i18n.t('admin.product_bundles_plugin.table.empty'),
  columns: [
    {
      key: 'title',
      label: i18n.t('admin.product_bundles_plugin.fields.title'),
      sortable: true,
      filterable: true,
      default: true,
      // The row's click-through reads this attribute: a table cell has nowhere
      // else to carry the record's id.
      render: (bundle) => <span data-product-bundle-id={bundle.id}>{bundle.title}</span>,
    },
    {
      key: 'status',
      label: i18n.t('admin.product_bundles_plugin.fields.status'),
      filterable: true,
      default: true,
      render: (bundle) => (
        <Badge variant={bundle.status === 'active' ? 'success' : 'secondary'}>
          {i18n.t(`admin.product_bundles_plugin.statuses.${bundle.status}`)}
        </Badge>
      ),
    },
    {
      key: 'components',
      label: i18n.t('admin.product_bundles_plugin.fields.components'),
      default: true,
      render: (bundle) => bundle.components.length,
    },
    {
      key: 'goods_price',
      label: i18n.t('admin.product_bundles_plugin.fields.goods_price'),
      default: true,
      className: 'text-right tabular-nums',
      render: (bundle) => formatAmount(bundle.goods_price, bundle.currency),
    },
    {
      key: 'price',
      label: i18n.t('admin.product_bundles_plugin.fields.price'),
      default: true,
      className: 'text-right tabular-nums',
      render: (bundle) => formatAmount(bundle.price, bundle.currency),
    },
    {
      key: 'saving',
      label: i18n.t('admin.product_bundles_plugin.fields.saving'),
      default: true,
      className: 'text-right tabular-nums',
      render: (bundle) => (bundle.saving > 0 ? formatAmount(bundle.saving, bundle.currency) : '—'),
    },
    {
      key: 'available',
      label: i18n.t('admin.product_bundles_plugin.fields.available'),
      default: false,
      className: 'text-right tabular-nums',
      render: (bundle) => bundle.available,
    },
  ],
})

defineDashboardPlugin({
  nav: {
    addChildren: {
      products: [
        {
          key: 'products.bundles',
          label: i18n.t('admin.product_bundles_plugin.nav'),
          path: '/product-bundles',
          position: 650,
          subject: 'Spree::ProductBundle',
        },
      ],
    },
  },
})

export { productBundlesClient } from './client'
export type { ProductBundle, ProductBundleParams } from './types'
