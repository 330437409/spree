import type { MembershipRight } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  PageHeader,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  ResourceLayout,
  RowActions,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { MembershipRightSheet } from '../../../../../../components/spree/membership-right-sheet'
import { useCustomerGroup } from '../../../../../../hooks/use-customer-groups'
import {
  useDeleteMembershipRight,
  useMembershipRights,
  useMembershipRightTypes,
} from '../../../../../../hooks/use-membership-rights'
import '../../../../../../tables/membership-rights'

const rightsSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
  edit: z.string().optional(),
})

export const Route = createFileRoute(
  '/_authenticated/$storeId/loyalty/memberships/$groupId/rights',
)({
  validateSearch: rightsSearchSchema,
  component: MembershipRightsPage,
})

/**
 * What one rung grants. A right is a row of the tier's own — its kind is
 * chosen from the registry and its settings are what that kind declares — so
 * the list is read and each one edited on its own, rather than inside the
 * tier's own sheet.
 */
function MembershipRightsPage() {
  const { t } = useTranslation()
  const { groupId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof rightsSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const { permissions } = usePermissions()

  // The tier's name is its group's: the settings row has none of its own.
  const { data: group } = useCustomerGroup(groupId)
  const { data: rightsData } = useMembershipRights(groupId)
  const { data: typesData } = useMembershipRightTypes()
  const deleteMutation = useDeleteMembershipRight(groupId)

  const rights = rightsData?.data ?? []
  const types = typesData?.data ?? []
  const editingRight = search.edit ? rights.find((right) => right.id === search.edit) : undefined
  const isCreating = !!search.new

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _new, edit: _edit, ...rest } = prev
        return rest as never
      },
    })

  useRowClickBridge('data-membership-right-id', openEdit)

  async function handleDelete(right: MembershipRight) {
    const ok = await confirm({
      title: t('admin.membership_rights.delete_confirm.title'),
      message: t('admin.membership_rights.delete_confirm.message', {
        name: right.name?.trim() || right.type,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    if (search.edit === right.id) closeSheet()
    await deleteMutation.mutateAsync(right.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={group?.name ?? ''}
            backTo="loyalty/memberships"
            actions={
              // A tier carries one right of each kind (the database says so), so
              // the door closes once every installed kind is here.
              types.length > rights.length ? (
                <Can I="create" a={Subject.MembershipRight}>
                  <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
                    <PlusIcon className="size-4" />
                    {t('admin.membership_rights.add_cta')}
                  </Button>
                </Can>
              ) : undefined
            }
          />
        }
        main={
          <ResourceTable<MembershipRight>
            hideHeader
            tableKey="membership-rights"
            // The mutation hooks invalidate +['customer-groups', groupId,
            // 'membership-rights']+, and ResourceTable injects the tenant id
            // between the first two slots, so the prefix-match still fires.
            queryKey={['customer-groups', groupId, 'membership-rights']}
            queryFn={(params) => adminClient.customerGroups.membershipRights.list(groupId, params)}
            searchParams={search}
            reorder={{
              onReorder: async (id, position) => {
                await adminClient.customerGroups.membershipRights.update(groupId, id, { position })
                queryClient.invalidateQueries({
                  queryKey: ['customer-groups', groupId, 'membership-rights'],
                })
              },
            }}
            rowActions={(right) => (
              <RowActions
                actions={[
                  { key: 'edit', onSelect: () => openEdit(right.id) },
                  {
                    key: 'delete',
                    destructive: true,
                    visible: permissions.can('destroy', Subject.MembershipRight),
                    disabled: deleteMutation.isPending,
                    onSelect: () => handleDelete(right),
                  },
                ]}
              />
            )}
          />
        }
      />

      {isCreating && (
        <MembershipRightSheet
          groupId={groupId}
          types={types}
          usedTypes={rights.map((right) => right.type)}
          onClose={closeSheet}
        />
      )}

      {editingRight && (
        <MembershipRightSheet
          groupId={groupId}
          right={editingRight}
          types={types}
          usedTypes={rights.map((right) => right.type)}
          onClose={closeSheet}
        />
      )}
    </>
  )
}
