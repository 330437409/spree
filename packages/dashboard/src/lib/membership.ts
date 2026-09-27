/**
 * The tier a card grants or a term holds, as both serializers name it: the
 * group's name and the ladder's rung, in a record the API answers shallowly —
 * it is a two-field projection of the tier, not the ladder's own row.
 */
export interface MembershipTierRef {
  name?: string
  rank?: number
}

/** The tier's name, or a dash while there is none to name. */
export function tierName(tier: Record<string, unknown> | null | undefined): string {
  return (tier as MembershipTierRef | null | undefined)?.name ?? '—'
}
