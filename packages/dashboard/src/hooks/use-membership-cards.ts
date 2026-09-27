import type { MembershipCard } from '@spree/admin-sdk'
import { adminClient, useResourceMutation } from '@spree/dashboard-core'
import i18n from 'i18next'

/**
 * Voiding a card the customer cannot — a lost phone, a fraud report. The same
 * transition the client's own 作废 runs, which is what keeps the term it started
 * and the tier's group in step.
 */
export function useRecycleMembershipCard() {
  return useResourceMutation<MembershipCard, Error, { id: string; reason?: string }>({
    mutationFn: ({ id, reason }) => adminClient.membershipCards.recycle(id, { reason }),
    // The ladder is untouched, but a card's own row and the member list both
    // change what they say about this customer.
    invalidate: [['membership-cards'], ['members']],
    successMessage: i18n.t('admin.membership_cards.messages.voided'),
    errorMessage: i18n.t('admin.membership_cards.messages.void_failed'),
    showValidationErrors: true,
  })
}
