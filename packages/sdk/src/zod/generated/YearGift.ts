// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { YearGiftCouponSchema } from './YearGiftCoupon';

export const YearGiftSchema = z.object({
  mode: z.string(),
  can_count: z.number(),
  usable_num: z.number(),
  coupons: z.array(YearGiftCouponSchema),
});

export type YearGift = z.infer<typeof YearGiftSchema>;
