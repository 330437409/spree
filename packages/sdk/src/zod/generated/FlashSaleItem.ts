// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleItemSchema = z.object({
  id: z.string(),
  variant_id: z.string().nullable(),
  product_id: z.string().nullable(),
  price: z.number().nullable(),
  sale_price: z.number(),
  remaining: z.number(),
});

export type FlashSaleItem = z.infer<typeof FlashSaleItemSchema>;
