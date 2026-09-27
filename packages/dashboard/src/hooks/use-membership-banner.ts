import type {
  MembershipBanner,
  MembershipBannerCreateParams,
  MembershipBannerUpdateParams,
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
    queryFn: () => adminClient.customerGroups.banner.get(groupId as string).catch(() => null),
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
  })
}
