// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CouponHoldingSchema = z.object({
  id: z.string(),
  code: z.string(),
  source: z.string(),
  status: z.string(),
  expires_at: z.string().nullable(),
  campaign_id: z.string().nullable(),
  promotion: z.record(z.string(), z.unknown()).nullable(),
});

export type CouponHolding = z.infer<typeof CouponHoldingSchema>;
