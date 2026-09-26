import type {
  MembershipTier,
  MembershipTierSetting,
  MembershipTierSettingCreateParams,
  MembershipTierSettingUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/** The ladder, for the table's `queryFn`. */
export function listMembershipTiers(params?: Record<string, unknown>) {
  return adminClient.membershipTiers.list(params)
}

/**
 * What makes the group a tier: its rank, what qualifies for it, the member price
 * it grants, and the settings it declares about itself.
 */
export function useMembershipTierSetting(groupId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('customer-groups', groupId ?? 'noop', 'tier-setting'),
    queryFn: () => adminClient.customerGroups.tierSetting.get(groupId as string),
    enabled: !!groupId,
  })
}

/**
 * Makes a customer group a tier. The group is picked first — a tier is the
 * group plus this row — so the write carries both.
 */
export function useCreateMembershipTier() {
  return useResourceMutation<
    MembershipTierSetting,
    Error,
    { groupId: string; params: MembershipTierSettingCreateParams }
  >({
    mutationFn: ({ groupId, params }) =>
      adminClient.customerGroups.tierSetting.create(groupId, params),
    invalidate: [['membership-tiers'], ['customer-groups']],
    successMessage: i18n.t('admin.membership_tiers.messages.created'),
    errorMessage: i18n.t('admin.membership_tiers.messages.create_failed'),
  })
}

export function useUpdateMembershipTierSetting(groupId: string) {
  return useResourceMutation<MembershipTierSetting, Error, MembershipTierSettingUpdateParams>({
    mutationFn: (params) => adminClient.customerGroups.tierSetting.update(groupId, params),
    invalidate: [['membership-tiers'], ['customer-groups', groupId, 'tier-setting']],
    successMessage: i18n.t('admin.membership_tiers.messages.updated'),
    errorMessage: i18n.t('admin.membership_tiers.messages.update_failed'),
  })
}

/** The rungs a picker may choose from, as the table reads them. */
export type { MembershipTier }
