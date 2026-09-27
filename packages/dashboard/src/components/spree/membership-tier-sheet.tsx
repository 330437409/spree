import { zodResolver } from '@hookform/resolvers/zod'
import {
  mapSpreeErrorsToForm,
  PreferencesForm,
  Subject,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  Switch,
} from '@spree/dashboard-ui'
import { ImageIcon, SparklesIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCustomerGroup } from '../../hooks/use-customer-groups'
import {
  useMembershipTierSetting,
  useUpdateMembershipTierSetting,
} from '../../hooks/use-membership-tiers'
import {
  MEMBERSHIP_TIER_DEFAULTS,
  type MembershipTierFormValues,
  membershipTierFormSchema,
  membershipTierToFormValues,
  membershipTierValuesToParams,
} from '../../schemas/membership-tier'

/**
 * One rung of the ladder: what qualifies for it, what it lasts and what it
 * grants. The ladder's order is not edited here — a rung is moved by dragging
 * it — and the rights it carries are edited on their own page, which the block
 * at the bottom links to.
 */
export function MembershipTierSheet({
  storeId,
  groupId,
  onClose,
}: {
  storeId: string
  groupId: string
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { store } = useStore()
  const { permissions } = usePermissions()
  const { data: setting, isLoading, isError } = useMembershipTierSetting(groupId)
  // The tier's name is its group's: the settings row has none of its own.
  const { data: group } = useCustomerGroup(groupId)
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
      onClose()
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) throw error
    }
  }

  const currency = store?.default_currency ?? ''
  const membershipPreferences = form.watch('preferences')

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="flex flex-col sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{group?.name ?? ''}</SheetTitle>
          <SheetDescription>{t('admin.membership_tiers.settings.help')}</SheetDescription>
        </SheetHeader>

        <form
          className="flex min-h-0 flex-1 flex-col"
          onSubmit={form.handleSubmit(onSubmit)}
          id="membership-tier-form"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {isLoading ? (
              <div className="flex flex-col gap-3">
                <Skeleton className="h-16 w-full rounded-lg" />
                <Skeleton className="h-16 w-full rounded-lg" />
                <Skeleton className="h-16 w-full rounded-lg" />
              </div>
            ) : isError || !setting ? (
              <p className="text-sm text-destructive" role="alert">
                {t('admin.membership_tiers.settings.unavailable')}
              </p>
            ) : (
              <>
                <FieldGroup>
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
                    <p className="text-xs text-muted-foreground">
                      {t('admin.membership_tiers.threshold.help')}
                    </p>
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
                    data-invalid={
                      form.formState.errors.member_discount_percentage ? true : undefined
                    }
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
                    <Input
                      id="membership-tier-sku"
                      disabled={!canUpdate}
                      {...form.register('sku')}
                    />
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

                {setting.preference_schema.length > 0 && (
                  <>
                    <div className="flex flex-col gap-1">
                      <span className="font-medium text-sm">
                        {t('admin.membership_tiers.copy.title')}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {t('admin.membership_tiers.copy.help')}
                      </span>
                    </div>
                    <PreferencesForm
                      schema={setting.preference_schema}
                      values={membershipPreferences}
                      onChange={(preferences) =>
                        form.setValue('preferences', preferences, { shouldDirty: true })
                      }
                    />
                  </>
                )}

                <RightsLink storeId={storeId} groupId={groupId} count={setting.rights_total} />
                <BannerLink storeId={storeId} groupId={groupId} />
              </>
            )}
          </div>

          <SheetFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('admin.actions.cancel')}
            </Button>
            {/* Save waits for the tier: the form holds its defaults until the
                read lands, and submitting those would blank every figure the
                operator never touched. */}
            <Button type="submit" disabled={!canUpdate || !setting || updateTier.isPending}>
              {t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

/**
 * What the tier carries, and the way to it: a right is edited on its own page,
 * where the kind it is and the settings that kind declares are the whole form.
 */
function RightsLink({
  storeId,
  groupId,
  count,
}: {
  storeId: string
  groupId: string
  count: number
}) {
  const { t } = useTranslation()

  return (
    <TierDetailLink
      storeId={storeId}
      groupId={groupId}
      path="rights"
      icon={<SparklesIcon className="size-4 text-muted-foreground" />}
      label={t('admin.membership_rights.count', { count })}
      cta={t('admin.membership_rights.manage')}
    />
  )
}

/** The banner those members see, and the way to it. */
function BannerLink({ storeId, groupId }: { storeId: string; groupId: string }) {
  const { t } = useTranslation()

  return (
    <TierDetailLink
      storeId={storeId}
      groupId={groupId}
      path="banner"
      icon={<ImageIcon className="size-4 text-muted-foreground" />}
      label={t('admin.membership_banners.title')}
      cta={t('admin.membership_banners.edit_cta')}
    />
  )
}

/** The two pages a tier has of its own, as the literals the router types against. */
const TIER_PAGES = {
  rights: '/$storeId/loyalty/memberships/$groupId/rights',
  banner: '/$storeId/loyalty/memberships/$groupId/banner',
} as const

/**
 * What the tier carries, and the way to it: the two things edited on pages of
 * their own — the rights it grants and the banner its members open on.
 */
function TierDetailLink({
  storeId,
  groupId,
  path,
  icon,
  label,
  cta,
}: {
  storeId: string
  groupId: string
  path: 'rights' | 'banner'
  icon: React.ReactNode
  label: string
  cta: string
}) {
  return (
    <div className="flex items-center justify-between rounded-md border bg-muted/40 px-3 py-2">
      <div className="flex items-center gap-2 text-sm">
        {icon}
        <span>{label}</span>
      </div>
      <Link
        to={TIER_PAGES[path]}
        params={{ storeId, groupId }}
        className="text-sm font-medium text-primary hover:underline"
      >
        {cta}
      </Link>
    </div>
  )
}
