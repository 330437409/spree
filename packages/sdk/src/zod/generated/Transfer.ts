// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TransferSchema = z.object({
  id: z.string(),
  status: z.string(),
  to_phone: z.any(),
  message: z.any(),
  transferable_type: z.string(),
  transferable_id: z.string().nullable(),
  from_customer_id: z.string().nullable(),
  to_customer_id: z.string().nullable(),
  expires_at: z.string().nullable(),
  accepted_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
});

export type Transfer = z.infer<typeof TransferSchema>;
