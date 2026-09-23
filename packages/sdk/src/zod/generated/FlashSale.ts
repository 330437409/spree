// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { FlashSaleItemSchema } from './FlashSaleItem';
import { FlashSaleSlotSchema } from './FlashSaleSlot';

export const FlashSaleSchema = z.object({
  id: z.string(),
  title: z.string().nullable(),
  code: z.string().nullable(),
  window_status: z.string(),
  starts_at: z.string().nullable(),
  ends_at: z.string().nullable(),
  server_now: z.string(),
  remaining: z.number(),
  percentage: z.number(),
  standby_tickets: z.number(),
  items: z.array(FlashSaleItemSchema),
  slots: z.array(FlashSaleSlotSchema),
});

export type FlashSale = z.infer<typeof FlashSaleSchema>;
