import type { MembershipTier } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell } from '@spree/dashboard-ui'
import { SparklesIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

defineTable<MembershipTier>('membership-tiers', {
  title: i18n.t('admin.membership_tiers.table.title'),
  description: i18n.t('admin.table_descriptions.membership_tiers'),
  // The tier has no name column of its own: its name is the group's, and the
  // ladder is searched through it.
  searchParam: 'customer_group_name_cont',
  searchPlaceholder: i18n.t('admin.membership_tiers.table.search_placeholder'),
  defaultSort: { field: 'rank', direction: 'asc' },
  emptyIcon: <SparklesIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.membership_tiers.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      // Not sortable: the ladder's order is the operator's, and the read answers
      // it in rank order whatever the table asks for.
      default: true,
      // A tier whose group is gone is history rather than a row to open: the
      // editor is the group's, and a group nobody has any more has none.
      render: (tier) =>
        tier.customer_group_id ? (
          <ResourceNameCell
            id={tier.customer_group_id}
            dataAttr="data-membership-tier-id"
            name={tier.name}
          />
        ) : (
          <span>{tier.name}</span>
        ),
    },
    {
      key: 'rank',
      label: i18n.t('admin.membership_tiers.columns.rank'),
      sortable: true,
      default: true,
      render: (tier) => tier.rank,
    },
    {
      key: 'threshold',
      label: i18n.t('admin.fields.threshold.label'),
      default: true,
      // The server formats it: the figure an operator reads in the store's own
      // currency, and nothing at all for a tier that asks for no basket.
      render: (tier) => tier.display_threshold ?? '—',
    },
    {
      key: 'validity_days',
      label: i18n.t('admin.membership_tiers.columns.validity_days'),
      default: true,
      render: (tier) => tier.validity_days ?? i18n.t('admin.membership_tiers.open_ended'),
    },
    {
      key: 'rights_total',
      label: i18n.t('admin.membership_tiers.columns.rights'),
      default: true,
      render: (tier) => tier.rights_total,
    },
  ],
})
