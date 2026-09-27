import type {
  MembershipBanner,
  MembershipBannerCreateParams,
  MembershipBannerUpdateParams,
  SpreeError,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/**
 * The banner the tier's members see, or nothing while it has none: the API
 * answers 404 for a tier without one, which is a state rather than a failure.
 */
export function useMembershipBanner(groupId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('customer-groups', groupId ?? 'noop', 'banner'),
    // A tier with no banner answers 404, which is a state; anything else is a
    // read that failed, and showing an empty editor for it would invite an
    // operator to write over a banner nobody could see.
    queryFn: async () => {
      try {
        return await adminClient.customerGroups.banner.get(groupId as string)
      } catch (error) {
        if ((error as SpreeError)?.status === 404) return null

        throw error
      }
    },
    enabled: !!groupId,
  })
}

/**
 * Writes the banner: an update when the tier already has one, a create when it
 * does not — one banner per tier, which is the API's own rule.
 */
export function useSaveMembershipBanner(groupId: string) {
  return useResourceMutation<
    MembershipBanner,
    Error,
    { exists: boolean; params: MembershipBannerCreateParams }
  >({
    mutationFn: ({ exists, params }) =>
      exists
        ? adminClient.customerGroups.banner.update(groupId, params as MembershipBannerUpdateParams)
        : adminClient.customerGroups.banner.create(groupId, params),
    invalidate: [['customer-groups', groupId, 'banner']],
    successMessage: i18n.t('admin.membership_banners.messages.saved'),
    errorMessage: i18n.t('admin.membership_banners.messages.save_failed'),
    // The page's own checks mirror the model's; what it refuses on its own
    // terms is said out loud rather than toasted away.
    showValidationErrors: true,
  })
}
