// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleSlotSchema = z.object({
  id: z.string(),
  starts_at: z.string().nullable(),
  ends_at: z.string().nullable(),
  window_status: z.string(),
  remaining: z.number(),
  purchase_cap: z.number().nullable(),
});

export type FlashSaleSlot = z.infer<typeof FlashSaleSlotSchema>;
