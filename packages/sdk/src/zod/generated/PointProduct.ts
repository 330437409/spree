// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PointProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  image: z.string().nullable(),
  category: z.string().nullable(),
  points: z.number(),
  featured: z.boolean(),
  stock: z.number(),
  type: z.string(),
  money: z.string().nullable(),
  in_stock: z.boolean(),
  variant_id: z.string().nullable(),
  vip_card: z.record(z.string(), z.unknown()).nullable(),
});

export type PointProduct = z.infer<typeof PointProductSchema>;
