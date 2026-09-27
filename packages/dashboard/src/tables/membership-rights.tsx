import type { MembershipRight } from '@spree/admin-sdk'
import { defineTable, typeLabel } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import { SparklesIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { useMembershipRightTypes } from '../hooks/use-membership-rights'

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
      render: (right) => <MembershipRightName right={right} />,
    },
    {
      key: 'type',
      label: i18n.t('admin.membership_rights.columns.kind'),
      default: true,
      render: (right) => <MembershipRightKind right={right} />,
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

/** A right with no wording of its own reads as the kind it is. */
function MembershipRightName({ right }: { right: MembershipRight }) {
  const kind = useKindLabel(right)

  return (
    <ResourceNameCell
      id={right.id}
      dataAttr="data-membership-right-id"
      name={right.name?.trim() || kind}
    />
  )
}

function MembershipRightKind({ right }: { right: MembershipRight }) {
  return <Badge variant="outline">{useKindLabel(right)}</Badge>
}

/**
 * The right's kind in words. Loads the kind catalog so a kind this dashboard
 * has no translation for still reads as the registry's own label rather than
 * its wire code.
 */
function useKindLabel(right: MembershipRight): string {
  const { data } = useMembershipRightTypes()
  const entry = (data?.data ?? []).find((type) => type.type === right.type)

  return typeLabel('membership_right', right.type, entry?.label)
}
