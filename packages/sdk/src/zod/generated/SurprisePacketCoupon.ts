// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SurprisePacketCouponSchema = z.object({
  promotion_id: z.string(),
  discount_type: z.string(),
  discount_minus: z.string().nullable(),
  discount_rate: z.string().nullable(),
  limit_amount_min: z.string().nullable(),
  instruction: z.string().nullable(),
  self_use: z.number(),
  friend_use: z.number(),
  grant_type: z.string(),
});

export type SurprisePacketCoupon = z.infer<typeof SurprisePacketCouponSchema>;
