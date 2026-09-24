// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MembershipCardSummarySchema } from './MembershipCardSummary';

export const MembershipCardTransferSchema = z.object({
  id: z.string(),
  token: z.string(),
  status: z.string(),
  message: z.string().nullable(),
  expires_at: z.string().nullable(),
  valid_from: z.string().nullable(),
  rights: z.array(z.any()),
  card: MembershipCardSummarySchema.nullable(),
});

export type MembershipCardTransfer = z.infer<typeof MembershipCardTransferSchema>;
