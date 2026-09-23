// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleSchema = z.object({
  id: z.string(),
  title: z.any(),
  code: z.any(),
  window_status: z.string(),
  starts_at: z.any(),
  ends_at: z.any(),
  server_now: z.any(),
  remaining: z.number(),
  percentage: z.number(),
  standby_tickets: z.number(),
  items: z.any(),
  slots: z.any(),
});

export type FlashSale = z.infer<typeof FlashSaleSchema>;
