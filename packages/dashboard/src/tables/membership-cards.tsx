import type { MembershipCard } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { CreditCardIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { membershipTierFilterProps } from '../hooks/use-membership-tiers'
import { cardEndsAt, tierName } from '../lib/membership'

/** A card's own vocabulary, in the order a support desk reads it. */
const CARD_STATUSES = ['active', 'dormant', 'recycled', 'expired'] as const
const CARD_SOURCES = ['purchase', 'grant'] as const

defineTable<MembershipCard>('membership-cards', {
  title: i18n.t('admin.nav.membership_cards'),
  description: i18n.t('admin.table_descriptions.membership_cards'),
  searchParam: 'customer_email_cont',
  searchPlaceholder: i18n.t('admin.membership_cards.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <CreditCardIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.membership_cards.empty'),
  columns: [
    {
      key: 'customer',
      label: i18n.t('admin.membership_cards.columns.customer'),
      default: true,
      render: (card) => (
        <ResourceNameCell
          id={card.id}
          dataAttr="data-membership-card-id"
          name={card.customer_email ?? '—'}
        />
      ),
    },
    {
      key: 'tier',
      label: i18n.t('admin.membership_cards.columns.tier'),
      ransackAttribute: 'customer_group_id',
      filterable: true,
      filterType: 'resource',
      filterResource: membershipTierFilterProps('membership-card-tier-filter'),
      default: true,
      render: (card) => tierName(card.tier),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: CARD_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`admin.membership_cards.status.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (card) => (
        <StatusBadge
          status={card.status}
          label={i18n.t(`admin.membership_cards.status.${card.status}`)}
        />
      ),
    },
    {
      key: 'source',
      label: i18n.t('admin.membership_cards.columns.source'),
      filterable: true,
      filterType: 'enum',
      filterOptions: CARD_SOURCES.map((source) => ({
        value: source,
        label: i18n.t(`admin.membership_cards.source.${source}`),
      })),
      default: false,
      render: (card) => i18n.t(`admin.membership_cards.source.${card.source}`),
    },
    {
      key: 'activated_at',
      label: i18n.t('admin.membership_cards.columns.activated_at'),
      sortable: true,
      default: true,
      render: (card) => (card.activated_at ? <RelativeTime iso={card.activated_at} /> : '—'),
    },
    {
      key: 'expires_at',
      label: i18n.t('admin.fields.expires_at.label'),
      default: true,
      // The window the card's own activation bought, read off the term it
      // started — a dormant card has none yet.
      render: (card) => {
        const endsAt = cardEndsAt(card)

        return endsAt ? <RelativeTime iso={endsAt} /> : '—'
      },
    },
  ],
})
