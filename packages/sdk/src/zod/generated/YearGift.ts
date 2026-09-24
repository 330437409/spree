// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const YearGiftSchema = z.object({
  mode: z.string(),
  can_count: z.number(),
  usable_num: z.number(),
  coupons: z.array(z.any()),
});

export type YearGift = z.infer<typeof YearGiftSchema>;
