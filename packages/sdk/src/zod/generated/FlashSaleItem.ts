// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleItemSchema = z.object({
  id: z.string(),
  variant_id: z.any(),
  product_id: z.any(),
  price: z.number().nullable(),
  sale_price: z.number(),
  remaining: z.any(),
});

export type FlashSaleItem = z.infer<typeof FlashSaleItemSchema>;
