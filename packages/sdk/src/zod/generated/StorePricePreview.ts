// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StorePricePreviewItemSchema } from './StorePricePreviewItem';

export const StorePricePreviewSchema = z.object({
  currency: z.string(),
  total: z.number().nullable(),
  quantity: z.number(),
  purchasable: z.boolean(),
  flags: z.record(z.string(), z.unknown()),
  balance_not_password: z.boolean(),
  items: z.array(StorePricePreviewItemSchema),
});

export type StorePricePreview = z.infer<typeof StorePricePreviewSchema>;
