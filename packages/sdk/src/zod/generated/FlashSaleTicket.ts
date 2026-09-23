// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleTicketSchema = z.object({
  id: z.string(),
  status: z.any(),
  quantity: z.number(),
  expires_at: z.string(),
  variant_id: z.any(),
  flash_sale_id: z.any(),
  flash_sale_slot_id: z.any(),
});

export type FlashSaleTicket = z.infer<typeof FlashSaleTicketSchema>;
