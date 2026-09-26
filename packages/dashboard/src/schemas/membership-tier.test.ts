import type { MembershipTierSetting } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import {
  MEMBERSHIP_TIER_DEFAULTS,
  membershipTierToFormValues,
  membershipTierValuesToParams,
} from './membership-tier'

function tierStub(overrides: Partial<MembershipTierSetting> = {}): MembershipTierSetting {
  return {
    id: 'mtier_1',
    rank: 3,
    threshold: '199.5',
    display_threshold: '$199.50',
    validity_days: 365,
    auto_renew: false,
    grace_days: 0,
    sku: null,
    member_discount_percentage: '10.0',
    rights_total: 2,
    preferences: { saving_order_title: '下单立省' },
    preference_schema: [],
    deleted_at: null,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...overrides,
  } as MembershipTierSetting
}

describe('membershipTierToFormValues', () => {
  it('holds figures as the strings a number input produces', () => {
    const values = membershipTierToFormValues(tierStub())

    expect(values).toMatchObject({
      rank: 3,
      threshold: '199.5',
      validity_days: '365',
      member_discount_percentage: '10.0',
      sku: '',
      preferences: { saving_order_title: '下单立省' },
    })
  })

  it('opens an unset figure blank rather than at nought', () => {
    const values = membershipTierToFormValues(
      tierStub({ threshold: null, validity_days: null, grace_days: null, sku: null }),
    )

    expect(values).toMatchObject({
      threshold: '',
      validity_days: '',
      grace_days: '',
      sku: '',
    })
  })
})

describe('membershipTierValuesToParams', () => {
  it('sends an unset figure as null rather than an empty string', () => {
    const params = membershipTierValuesToParams(MEMBERSHIP_TIER_DEFAULTS)

    expect(params).toMatchObject({
      threshold: null,
      validity_days: null,
      sku: null,
      member_discount_percentage: null,
      grace_days: 0,
    })
  })

  // Clearing the member price is a decision the server acts on; an empty string
  // reaching it as "" would be a field nobody wrote.
  it('sends a cleared member price as null', () => {
    const params = membershipTierValuesToParams({
      ...MEMBERSHIP_TIER_DEFAULTS,
      member_discount_percentage: '',
    })

    expect(params.member_discount_percentage).toBeNull()
  })

  it('sends the figures as written', () => {
    const params = membershipTierValuesToParams({
      ...MEMBERSHIP_TIER_DEFAULTS,
      rank: 2,
      threshold: '199.5',
      validity_days: '365',
      member_discount_percentage: '10',
      grace_days: '7',
      sku: ' vip-1 ',
    })

    expect(params).toMatchObject({
      rank: 2,
      threshold: '199.5',
      validity_days: 365,
      member_discount_percentage: '10',
      grace_days: 7,
      sku: 'vip-1',
    })
  })
})
