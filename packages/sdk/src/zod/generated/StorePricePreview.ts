// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StorePricePreviewItemSchema } from './StorePricePreviewItem';

export const StorePricePreviewSchema = z.object({
  currency: z.string(),
  total: z.number(),
  quantity: z.number(),
  purchasable: z.boolean(),
  items: z.array(StorePricePreviewItemSchema),
});

export type StorePricePreview = z.infer<typeof StorePricePreviewSchema>;
