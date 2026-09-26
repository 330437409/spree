import { zodResolver } from '@hookform/resolvers/zod'
import {
  mapSpreeErrorsToForm,
  PageHeader,
  PreferencesForm,
  Subject,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  ErrorState,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  FormActions,
  FormSection,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  ResourceLayout,
  Skeleton,
  Switch,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { MembershipRightsSection } from '../../../../../components/spree/membership-rights-section'
import { useCustomerGroup } from '../../../../../hooks/use-customer-groups'
import {
  useMembershipTierSetting,
  useUpdateMembershipTierSetting,
} from '../../../../../hooks/use-membership-tiers'
import {
  MEMBERSHIP_TIER_DEFAULTS,
  type MembershipTierFormValues,
  membershipTierFormSchema,
  membershipTierToFormValues,
  membershipTierValuesToParams,
} from '../../../../../schemas/membership-tier'

export const Route = createFileRoute('/_authenticated/$storeId/loyalty/memberships/$groupId')({
  component: MembershipTierPage,
})

/**
 * A tier is a customer group carrying settings, so this page is the group's:
 * what qualifies for it, what it grants a member, and what it claims about
 * itself. The rights hang below, each edited on its own.
 */
function MembershipTierPage() {
  const { t } = useTranslation()
  const { groupId } = Route.useParams()
  const { store } = useStore()
  const { permissions } = usePermissions()
  const { data: group } = useCustomerGroup(groupId)
  const { data: setting, isLoading, isError } = useMembershipTierSetting(groupId)
  const updateTier = useUpdateMembershipTierSetting(groupId)
  const canUpdate = permissions.can('update', Subject.MembershipTierSetting)

  const form = useForm<MembershipTierFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(membershipTierFormSchema) as any,
    defaultValues: MEMBERSHIP_TIER_DEFAULTS,
  })

  useEffect(() => {
    if (!setting || form.formState.isDirty) return
    form.reset(membershipTierToFormValues(setting))
  }, [setting, form])

  async function onSubmit(values: MembershipTierFormValues) {
    try {
      await updateTier.mutateAsync(membershipTierValuesToParams(values))
      form.reset(values)
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) throw error
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  if (isLoading) return <MembershipTierSkeleton />
  if (isError || !setting) return <ErrorState />

  const currency = store?.default_currency ?? ''
  const membershipPreferences = form.watch('preferences')

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={group?.name ?? ''}
            backTo="loyalty/memberships"
            actions={canUpdate ? <FormActions form={form} /> : undefined}
          />
        }
        main={
          <>
            <FormSection
              title={t('admin.membership_tiers.settings.title')}
              description={t('admin.membership_tiers.settings.help')}
            >
              <FieldGroup>
                <Field data-invalid={form.formState.errors.rank ? true : undefined}>
                  <FieldLabel htmlFor="membership-tier-rank">
                    {t('admin.membership_tiers.columns.rank')}
                  </FieldLabel>
                  <Input
                    id="membership-tier-rank"
                    type="number"
                    inputMode="numeric"
                    disabled={!canUpdate}
                    {...form.register('rank')}
                  />
                  <FieldError errors={[form.formState.errors.rank]} />
                </Field>

                <Field data-invalid={form.formState.errors.threshold ? true : undefined}>
                  <FieldLabel htmlFor="membership-tier-threshold">
                    {t('admin.fields.threshold.label')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupAddon>
                      <InputGroupText>{currency}</InputGroupText>
                    </InputGroupAddon>
                    <InputGroupInput
                      id="membership-tier-threshold"
                      type="number"
                      inputMode="decimal"
                      disabled={!canUpdate}
                      {...form.register('threshold')}
                    />
                  </InputGroup>
                  <FieldError errors={[form.formState.errors.threshold]} />
                </Field>

                <Field data-invalid={form.formState.errors.validity_days ? true : undefined}>
                  <FieldLabel htmlFor="membership-tier-validity">
                    {t('admin.membership_tiers.columns.validity_days')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupInput
                      id="membership-tier-validity"
                      type="number"
                      inputMode="numeric"
                      disabled={!canUpdate}
                      {...form.register('validity_days')}
                    />
                    <InputGroupAddon align="inline-end">
                      <InputGroupText>{t('admin.membership_tiers.days_suffix')}</InputGroupText>
                    </InputGroupAddon>
                  </InputGroup>
                  <FieldError errors={[form.formState.errors.validity_days]} />
                </Field>

                <Field
                  data-invalid={form.formState.errors.member_discount_percentage ? true : undefined}
                >
                  <FieldLabel htmlFor="membership-tier-discount">
                    {t('admin.membership_tiers.member_discount.label')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupInput
                      id="membership-tier-discount"
                      type="number"
                      inputMode="decimal"
                      disabled={!canUpdate}
                      {...form.register('member_discount_percentage')}
                    />
                    <InputGroupAddon align="inline-end">
                      <InputGroupText>%</InputGroupText>
                    </InputGroupAddon>
                  </InputGroup>
                  <p className="text-xs text-muted-foreground">
                    {t('admin.membership_tiers.member_discount.help')}
                  </p>
                  <FieldError errors={[form.formState.errors.member_discount_percentage]} />
                </Field>

                <Field data-invalid={form.formState.errors.sku ? true : undefined}>
                  <FieldLabel htmlFor="membership-tier-sku">
                    {t('admin.membership_tiers.sku.label')}
                  </FieldLabel>
                  <Input id="membership-tier-sku" disabled={!canUpdate} {...form.register('sku')} />
                  <p className="text-xs text-muted-foreground">
                    {t('admin.membership_tiers.sku.help')}
                  </p>
                  <FieldError errors={[form.formState.errors.sku]} />
                </Field>

                <Field data-invalid={form.formState.errors.grace_days ? true : undefined}>
                  <FieldLabel htmlFor="membership-tier-grace">
                    {t('admin.membership_tiers.grace_days.label')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupInput
                      id="membership-tier-grace"
                      type="number"
                      inputMode="numeric"
                      disabled={!canUpdate}
                      {...form.register('grace_days')}
                    />
                    <InputGroupAddon align="inline-end">
                      <InputGroupText>{t('admin.membership_tiers.days_suffix')}</InputGroupText>
                    </InputGroupAddon>
                  </InputGroup>
                  <p className="text-xs text-muted-foreground">
                    {t('admin.membership_tiers.grace_days.help')}
                  </p>
                  <FieldError errors={[form.formState.errors.grace_days]} />
                </Field>

                <Field orientation="horizontal">
                  <FieldLabel htmlFor="membership-tier-auto-renew">
                    {t('admin.membership_tiers.auto_renew.label')}
                  </FieldLabel>
                  <Controller
                    control={form.control}
                    name="auto_renew"
                    render={({ field }) => (
                      <Switch
                        id="membership-tier-auto-renew"
                        checked={field.value}
                        disabled={!canUpdate}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </Field>
              </FieldGroup>
            </FormSection>

            {setting.preference_schema.length > 0 && (
              <FormSection
                title={t('admin.membership_tiers.copy.title')}
                description={t('admin.membership_tiers.copy.help')}
              >
                <PreferencesForm
                  schema={setting.preference_schema}
                  values={membershipPreferences}
                  onChange={(preferences) =>
                    form.setValue('preferences', preferences, { shouldDirty: true })
                  }
                />
              </FormSection>
            )}

            <MembershipRightsSection groupId={groupId} />
          </>
        }
      />
    </form>
  )
}

function MembershipTierSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Skeleton className="h-8 w-48" />
        <div className="ml-auto flex items-center gap-2">
          <Skeleton className="h-8 w-16 rounded-lg" />
        </div>
      </div>
      <div className="flex flex-col gap-6">
        <Skeleton className="h-96 w-full rounded-xl" />
        <Skeleton className="h-48 w-full rounded-xl" />
      </div>
    </div>
  )
}
