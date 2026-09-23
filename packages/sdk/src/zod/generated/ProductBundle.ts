// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { BundleComponentSchema } from './BundleComponent';

export const ProductBundleSchema = z.object({
  id: z.string(),
  title: z.string(),
  slug: z.string(),
  goods_price: z.number(),
  price: z.number(),
  saving: z.number(),
  available: z.number(),
  seller_id: z.string().nullable(),
  components: z.array(BundleComponentSchema),
});

export type ProductBundle = z.infer<typeof ProductBundleSchema>;
