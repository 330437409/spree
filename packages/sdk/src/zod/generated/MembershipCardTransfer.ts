// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipCardTransferSchema = z.object({
  id: z.string(),
  token: z.any(),
  status: z.string(),
  message: z.string().nullable(),
  expires_at: z.string().nullable(),
  card: z.record(z.string(), z.unknown()).nullable(),
});

export type MembershipCardTransfer = z.infer<typeof MembershipCardTransferSchema>;
