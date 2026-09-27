import { zodResolver } from '@hookform/resolvers/zod'
import type { MembershipTier } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceCombobox,
  ResourceTable,
  resourceSearchSchema,
  Subject,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { MembershipTierSheet } from '../../../../../components/spree/membership-tier-sheet'
import { customerGroupAutocompleteProps } from '../../../../../hooks/use-customer-groups'
import {
  listMembershipTiers,
  useCreateMembershipTier,
} from '../../../../../hooks/use-membership-tiers'
import '../../../../../tables/membership-tiers'

const membershipTiersSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
  edit: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/loyalty/memberships/')({
  validateSearch: membershipTiersSearchSchema,
  component: MembershipTiersPage,
})

function MembershipTiersPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof membershipTiersSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const editGroupId = search.edit
  const isCreating = !!search.new

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (groupId: string) =>
    navigate({
      search: (prev: Record<string, unknown>) => ({ ...prev, edit: groupId }) as never,
    })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _new, edit: _edit, ...rest } = prev
        return rest as never
      },
    })

  // Making one hands straight over to editing it: the creating sheet closes as
  // the tier's own opens, rather than stacking on top of it.
  const openCreated = (groupId: string) =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _new, ...rest } = prev
        return { ...rest, edit: groupId } as never
      },
    })

  useRowClickBridge('data-membership-tier-id', openEdit)

  return (
    <>
      <ResourceTable<MembershipTier>
        tableKey="membership-tiers"
        queryKey="membership-tiers"
        queryFn={listMembershipTiers}
        searchParams={search}
        // The ladder's order is the operator's and they arrange it by dragging
        // a rung: the table's own reorder drops it at the position it was
        // dropped in, and the server settles every rank behind it.
        reorder={{
          positionField: 'rank',
          onReorder: async (id, position) => {
            await adminClient.membershipTiers.reposition(id, { new_position: position })
            queryClient.invalidateQueries({ queryKey: ['membership-tiers'] })
          },
        }}
        rowActions={(tier) =>
          tier.customer_group_id ? (
            <RowActions
              actions={[
                { key: 'edit', onSelect: () => openEdit(tier.customer_group_id as string) },
              ]}
            />
          ) : null
        }
        actions={
          <Can I="create" a={Subject.MembershipTierSetting}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.membership_tiers.new_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <NewTierSheet onClose={closeSheet} onCreated={openCreated} />}
      {editGroupId && (
        <MembershipTierSheet storeId={storeId} groupId={editGroupId} onClose={closeSheet} />
      )}
    </>
  )
}

const newTierFormSchema = z.object({
  customer_group_id: z.string().min(1),
})

type NewTierFormValues = z.infer<typeof newTierFormSchema>

/**
 * A tier is a customer group carrying settings, so making one is picking the
 * group: the rung it takes is the ladder's own — it joins the end until the
 * operator drags it — and a group that is already a tier is refused by the
 * server rather than filtered out of a list the picker is still searching.
 */
function NewTierSheet({
  onClose,
  onCreated,
}: {
  onClose: () => void
  onCreated: (groupId: string) => void
}) {
  const { t } = useTranslation()
  const createTier = useCreateMembershipTier()
  const form = useForm<NewTierFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(newTierFormSchema) as any,
    defaultValues: { customer_group_id: '' },
  })

  async function handleSubmit(values: NewTierFormValues) {
    try {
      await createTier.mutateAsync({ groupId: values.customer_group_id, params: {} })
      onCreated(values.customer_group_id)
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) throw error
    }
  }

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="flex flex-col sm:max-w-md">
        <SheetHeader>
          <SheetTitle>{t('admin.membership_tiers.new.title')}</SheetTitle>
          <SheetDescription>{t('admin.membership_tiers.new.description')}</SheetDescription>
        </SheetHeader>

        <form className="flex min-h-0 flex-1 flex-col" onSubmit={form.handleSubmit(handleSubmit)}>
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              <Controller
                control={form.control}
                name="customer_group_id"
                render={({ field, fieldState }) => (
                  <Field data-invalid={fieldState.invalid}>
                    <FieldLabel htmlFor="membership-tier-group">
                      {t('admin.membership_tiers.new.group_label')}
                    </FieldLabel>
                    <ResourceCombobox
                      id="membership-tier-group"
                      value={field.value || null}
                      onChange={(value) => field.onChange(value ?? '')}
                      {...customerGroupAutocompleteProps('membership-tier-group-picker')}
                    />
                    <FieldError errors={[fieldState.error]} />
                  </Field>
                )}
              />
            </FieldGroup>
          </div>

          <SheetFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={createTier.isPending}>
              {t('admin.membership_tiers.new.submit')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
