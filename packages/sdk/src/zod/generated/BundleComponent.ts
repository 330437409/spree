// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BundleComponentSchema = z.object({
  id: z.string(),
  variant_id: z.any(),
  product_id: z.any(),
  name: z.string().nullable(),
  quantity: z.number(),
  price: z.number().nullable(),
  goods_amount: z.number().nullable(),
  available: z.number(),
  in_stock: z.boolean(),
  image_url: z.string().nullable(),
});

export type BundleComponent = z.infer<typeof BundleComponentSchema>;
