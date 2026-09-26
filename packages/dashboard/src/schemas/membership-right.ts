import type { MembershipRight, MembershipRightUpdateParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { z } from 'zod/v4'

/**
 * One right of a tier. The `type` is the registry shorthand the picker chose,
 * and `preferences` is what that kind grants — keyed as the kind's own
 * `preference_schema` names the keys, so the form renders whatever a kind
 * declares without knowing one of them.
 */
export const membershipRightFormSchema = z.object({
  type: z.string(),
  name: z.string().optional(),
  description: z.string().optional(),
  preferences: z.record(z.string(), z.unknown()).default({}),
})

export type MembershipRightFormValues = z.infer<typeof membershipRightFormSchema>

export function membershipRightToFormValues(right: MembershipRight): MembershipRightFormValues {
  return {
    type: right.type,
    name: right.name ?? '',
    description: right.description ?? '',
    preferences: { ...(right.preferences ?? {}) } as Record<string, unknown>,
  }
}

export function membershipRightValuesToParams(
  values: MembershipRightFormValues,
): MembershipRightUpdateParams {
  return {
    name: blankToNull(values.name),
    description: blankToNull(values.description),
    preferences: values.preferences,
  }
}
