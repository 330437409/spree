// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MembershipCardTransferSchema } from './MembershipCardTransfer';

export const MembershipCardSchema = z.object({
  id: z.string(),
  tier: z.record(z.string(), z.unknown()).nullable(),
  status: z.string(),
  source: z.string(),
  entry_bag: z.record(z.string(), z.unknown()).nullable(),
  giftable: z.boolean(),
  activates_before: z.string().nullable(),
  activated_at: z.string().nullable(),
  membership: z.record(z.string(), z.unknown()).nullable(),
  transfer: MembershipCardTransferSchema.nullable(),
});

export type MembershipCard = z.infer<typeof MembershipCardSchema>;
