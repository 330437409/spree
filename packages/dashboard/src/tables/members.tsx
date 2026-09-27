import type { Membership } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { UsersIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { membershipTierFilterProps } from '../hooks/use-membership-tiers'
import { tierName } from '../lib/membership'

/** A term's own vocabulary, in the order it is worth reading. */
const TERM_STATUSES = ['active', 'past_due', 'pending', 'expired', 'cancelled'] as const

defineTable<Membership>('members', {
  title: i18n.t('admin.nav.members'),
  description: i18n.t('admin.table_descriptions.members'),
  // The question a support desk asks is the one a customer can answer: the
  // address they wrote in with.
  searchParam: 'customer_email_cont',
  searchPlaceholder: i18n.t('admin.members.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <UsersIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.members.empty'),
  columns: [
    {
      key: 'customer',
      label: i18n.t('admin.members.columns.customer'),
      default: true,
      // The email is the search the operator just made, so it is the cell they
      // read back; the row it belongs to is the term, which the cell opens.
      render: (term) => (
        <ResourceNameCell
          id={term.id}
          dataAttr="data-member-id"
          name={term.customer_email ?? '—'}
        />
      ),
    },
    {
      key: 'tier',
      label: i18n.t('admin.members.columns.tier'),
      ransackAttribute: 'customer_group_id',
      filterable: true,
      filterType: 'resource',
      filterResource: membershipTierFilterProps('member-tier-filter'),
      default: true,
      render: (term) => tierName(term.tier),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: TERM_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`admin.members.status.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (term) => (
        <StatusBadge status={term.status} label={i18n.t(`admin.members.status.${term.status}`)} />
      ),
    },
    {
      key: 'starts_at',
      label: i18n.t('admin.members.columns.starts_at'),
      sortable: true,
      default: true,
      render: (term) => (term.starts_at ? <RelativeTime iso={term.starts_at} /> : '—'),
    },
    {
      key: 'ends_at',
      label: i18n.t('admin.members.columns.ends_at'),
      sortable: true,
      default: true,
      // A term with no end is an operator grant that never lapses, which is not
      // the same as one nobody has written yet.
      render: (term) =>
        term.ends_at ? <RelativeTime iso={term.ends_at} /> : i18n.t('admin.members.open_ended'),
    },
  ],
})
