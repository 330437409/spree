import type { MembershipRight, MembershipRightUpdateParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'

/**
 * One right of a tier: the operator's own wording for it and what its kind
 * grants — keyed as the kind's own `preference_schema` names the keys, so the
 * form renders whatever a kind declares without knowing one of them. The kind
 * itself is not part of this: it is chosen once, when the right is added, and
 * the registry is what says what it means.
 */
export interface MembershipRightFormValues {
  name: string
  description: string
  preferences: Record<string, unknown>
}

export function membershipRightToFormValues(right: MembershipRight): MembershipRightFormValues {
  return {
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
