// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StorePricePreviewItemSchema = z.object({
  variant_id: z.string().nullable(),
  product_id: z.string().nullable(),
  quantity: z.number(),
  unit_amount: z.number().nullable(),
  compare_at_amount: z.number().nullable(),
  total: z.number().nullable(),
  price_list_id: z.string().nullable(),
  price_source: z.string().nullable(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  purchasable: z.boolean(),
  available_quantity: z.number(),
});

export type StorePricePreviewItem = z.infer<typeof StorePricePreviewItemSchema>;
