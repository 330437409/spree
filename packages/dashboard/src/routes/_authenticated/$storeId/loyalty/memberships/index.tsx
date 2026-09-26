import { zodResolver } from '@hookform/resolvers/zod'
import type { MembershipTier } from '@spree/admin-sdk'
import {
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
  Input,
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
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { customerGroupAutocompleteProps } from '../../../../../hooks/use-customer-groups'
import {
  listMembershipTiers,
  useCreateMembershipTier,
} from '../../../../../hooks/use-membership-tiers'
import '../../../../../tables/membership-tiers'

const membershipTiersSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
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

  const isCreating = !!search.new

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _new, ...rest } = prev
        return rest as never
      },
    })

  const openTier = (groupId: string) =>
    navigate({
      to: '/$storeId/loyalty/memberships/$groupId',
      params: { storeId, groupId },
    })

  useRowClickBridge('data-membership-tier-id', openTier)

  return (
    <>
      <ResourceTable<MembershipTier>
        tableKey="membership-tiers"
        queryKey="membership-tiers"
        queryFn={listMembershipTiers}
        searchParams={search}
        // The rung is a group carrying settings, so the row it opens is the
        // group's — the ladder is read here and edited there.
        rowActions={(tier) =>
          tier.customer_group_id ? (
            <RowActions
              actions={[
                { key: 'edit', onSelect: () => openTier(tier.customer_group_id as string) },
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

      {isCreating && <NewTierSheet onClose={closeSheet} onCreated={openTier} />}
    </>
  )
}

const newTierFormSchema = z.object({
  customer_group_id: z.string().min(1),
  rank: z.coerce.number().int().min(0),
})

type NewTierFormValues = z.infer<typeof newTierFormSchema>

/**
 * A tier is a customer group carrying settings, so making one is picking the
 * group: the ladder order is the operator's, and a group that is already a tier
 * is refused by the server rather than filtered out of a list the picker is
 * still searching.
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
    defaultValues: { customer_group_id: '', rank: 1 },
  })

  async function handleSubmit(values: NewTierFormValues) {
    try {
      await createTier.mutateAsync({
        groupId: values.customer_group_id,
        params: { rank: values.rank },
      })
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

              <Field data-invalid={form.formState.errors.rank?.message ? true : undefined}>
                <FieldLabel htmlFor="membership-tier-rank">
                  {t('admin.membership_tiers.columns.rank')}
                </FieldLabel>
                <Input
                  id="membership-tier-rank"
                  type="number"
                  inputMode="numeric"
                  {...form.register('rank')}
                />
                <FieldError errors={[form.formState.errors.rank]} />
              </Field>
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
