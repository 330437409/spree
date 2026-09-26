import type {
  MembershipTierSetting,
  MembershipTierSettingCreateParams,
  MembershipTierSettingUpdateParams,
} from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { z } from 'zod/v4'

/**
 * The figures are held as the strings a number input produces — an empty one
 * means the tier states no threshold, no member price or no length, which are
 * not the same as nought.
 */
export const membershipTierFormSchema = z.object({
  rank: z.coerce.number().int().min(0),
  threshold: z.string().optional(),
  validity_days: z.string().optional(),
  auto_renew: z.boolean(),
  grace_days: z.string().optional(),
  sku: z.string().optional(),
  member_discount_percentage: z.string().optional(),
  // What the tier says about itself, keyed as its own `preference_schema`
  // names the keys. Held shallow on purpose — the fields are rendered from the
  // schema the row carries, so the form never learns a single key.
  preferences: z.record(z.string(), z.unknown()).default({}),
})

export type MembershipTierFormValues = z.infer<typeof membershipTierFormSchema>

export const MEMBERSHIP_TIER_DEFAULTS: MembershipTierFormValues = {
  rank: 0,
  threshold: '',
  validity_days: '',
  auto_renew: false,
  grace_days: '',
  sku: '',
  member_discount_percentage: '',
  preferences: {},
}

export function membershipTierToFormValues(
  setting: MembershipTierSetting,
): MembershipTierFormValues {
  return {
    rank: setting.rank,
    threshold: setting.threshold == null ? '' : String(setting.threshold),
    validity_days: setting.validity_days == null ? '' : String(setting.validity_days),
    auto_renew: setting.auto_renew,
    grace_days: setting.grace_days == null ? '' : String(setting.grace_days),
    sku: setting.sku ?? '',
    member_discount_percentage:
      setting.member_discount_percentage == null ? '' : String(setting.member_discount_percentage),
    preferences: { ...(setting.preferences ?? {}) } as Record<string, unknown>,
  }
}

function decimalOrNull(value: string | undefined): string | null {
  const trimmed = value?.trim()
  return trimmed ? trimmed : null
}

function integerOrNull(value: string | undefined): number | null {
  const trimmed = value?.trim()
  return trimmed ? Number(trimmed) : null
}

export function membershipTierValuesToParams(
  values: MembershipTierFormValues,
): MembershipTierSettingCreateParams & MembershipTierSettingUpdateParams {
  return {
    rank: values.rank,
    threshold: decimalOrNull(values.threshold),
    validity_days: integerOrNull(values.validity_days),
    auto_renew: values.auto_renew,
    grace_days: Number(values.grace_days?.trim() || 0),
    sku: blankToNull(values.sku),
    member_discount_percentage: decimalOrNull(values.member_discount_percentage),
    preferences: values.preferences,
  }
}
