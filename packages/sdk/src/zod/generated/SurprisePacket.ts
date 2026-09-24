// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { SurprisePacketCouponSchema } from './SurprisePacketCoupon';

export const SurprisePacketSchema = z.object({
  coupons: z.array(SurprisePacketCouponSchema),
  total_money_sum: z.string(),
  exchange: z.boolean(),
  other_type: z.string().nullable(),
});

export type SurprisePacket = z.infer<typeof SurprisePacketSchema>;
