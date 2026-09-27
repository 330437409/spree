import type { MembershipRight } from '@spree/admin-sdk'
import { defineTable, typeLabel } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import { SparklesIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

defineTable<MembershipRight>('membership-rights', {
  title: i18n.t('admin.membership_rights.title'),
  description: i18n.t('admin.membership_rights.help'),
  // The operator's own wording is what they search their own list by; the kind
  // is a label they pick from, not a thing they spell.
  searchParam: 'name_cont',
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <SparklesIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.membership_rights.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      default: true,
      render: (right) => (
        <ResourceNameCell
          id={right.id}
          dataAttr="data-membership-right-id"
          name={right.name?.trim() || typeLabel('membership_right', right.type)}
        />
      ),
    },
    {
      key: 'type',
      label: i18n.t('admin.membership_rights.columns.kind'),
      default: true,
      render: (right) => typeLabel('membership_right', right.type),
    },
    {
      key: 'published',
      label: i18n.t('admin.membership_rights.columns.published'),
      default: true,
      render: (right) => (
        <ActiveBadge
          active={right.published}
          activeLabel={i18n.t('admin.membership_rights.status.published')}
          inactiveLabel={i18n.t('admin.membership_rights.status.draft')}
        />
      ),
    },
  ],
})
