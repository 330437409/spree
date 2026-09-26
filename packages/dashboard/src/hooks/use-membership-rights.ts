import type {
  MembershipRight,
  MembershipRightCreateParams,
  MembershipRightUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/** The rights a tier carries, in the order the tier presents them. */
export function useMembershipRights(groupId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('customer-groups', groupId ?? 'noop', 'membership-rights'),
    queryFn: () =>
      adminClient.customerGroups.membershipRights.list(groupId as string, {
        limit: 100,
        sort: 'position',
      }),
    enabled: !!groupId,
  })
}

/**
 * The kinds a right may be, as the registry declares them — the picker an
 * operator adds one from, and the schema an existing right's settings form
 * renders. Static at runtime: a kind is a class, so the list cannot change
 * without a deploy.
 */
export function useMembershipRightTypes() {
  return useQuery({
    queryKey: ['membership-rights', 'types'],
    queryFn: () => adminClient.membershipRights.types(),
    staleTime: Number.POSITIVE_INFINITY,
  })
}

export function useCreateMembershipRight(groupId: string) {
  return useResourceMutation<MembershipRight, Error, MembershipRightCreateParams>({
    mutationFn: (params) => adminClient.customerGroups.membershipRights.create(groupId, params),
    invalidate: [['customer-groups', groupId, 'membership-rights'], ['membership-tiers']],
    successMessage: i18n.t('admin.membership_rights.messages.created'),
    errorMessage: i18n.t('admin.membership_rights.messages.create_failed'),
    // The panel writes per right and has no form to hang a refusal on: a kind
    // the tier already carries, or a setting its kind refuses, is said out loud.
    showValidationErrors: true,
  })
}

export function useUpdateMembershipRight(groupId: string) {
  return useResourceMutation<
    MembershipRight,
    Error,
    { id: string; params: MembershipRightUpdateParams }
  >({
    mutationFn: ({ id, params }) =>
      adminClient.customerGroups.membershipRights.update(groupId, id, params),
    invalidate: [['customer-groups', groupId, 'membership-rights'], ['membership-tiers']],
    successMessage: i18n.t('admin.membership_rights.messages.updated'),
    errorMessage: i18n.t('admin.membership_rights.messages.update_failed'),
    showValidationErrors: true,
  })
}

export function useDeleteMembershipRight(groupId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.customerGroups.membershipRights.delete(groupId, id),
    invalidate: [['customer-groups', groupId, 'membership-rights'], ['membership-tiers']],
    successMessage: i18n.t('admin.membership_rights.messages.deleted'),
    errorMessage: i18n.t('admin.membership_rights.messages.delete_failed'),
    showValidationErrors: true,
  })
}
