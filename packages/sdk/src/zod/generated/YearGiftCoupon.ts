// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const YearGiftCouponSchema = z.object({
  promotion_id: z.string(),
  name: z.string(),
  claimed: z.boolean(),
});

export type YearGiftCoupon = z.infer<typeof YearGiftCouponSchema>;
