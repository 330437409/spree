// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CouponPromotionSchema = z.object({
  name: z.string(),
});

export type CouponPromotion = z.infer<typeof CouponPromotionSchema>;
