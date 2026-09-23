// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { LineItemSchema } from './LineItem';

export const CartProductBundleSchema = z.object({
  id: z.string(),
  title: z.string(),
  slug: z.string(),
  bundle_id: z.string().nullable(),
  quantity: z.number(),
  goods_price: z.number(),
  price: z.number(),
  saving: z.number(),
  available: z.number(),
  line_items: z.array(LineItemSchema),
});

export type CartProductBundle = z.infer<typeof CartProductBundleSchema>;
