// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MembershipCardSummarySchema } from './MembershipCardSummary';
import { MembershipRightSchema } from './MembershipRight';

export const MembershipCardVoucherSchema = z.object({
  id: z.string(),
  token: z.string(),
  status: z.string(),
  message: z.string().nullable(),
  expires_at: z.string().nullable(),
  valid_from: z.string().nullable(),
  rights: z.array(MembershipRightSchema),
  card: MembershipCardSummarySchema.nullable(),
});

export type MembershipCardVoucher = z.infer<typeof MembershipCardVoucherSchema>;
