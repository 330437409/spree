// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleSlotSchema = z.object({
  id: z.string(),
  starts_at: z.any(),
  ends_at: z.any(),
  window_status: z.string(),
  remaining: z.number(),
  purchase_cap: z.any(),
});

export type FlashSaleSlot = z.infer<typeof FlashSaleSlotSchema>;
