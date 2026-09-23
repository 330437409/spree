// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FlashSaleTicketSchema = z.object({
  id: z.string(),
  status: z.string(),
  quantity: z.number(),
  expires_at: z.string(),
  variant_id: z.string().nullable(),
  flash_sale_id: z.string().nullable(),
  flash_sale_slot_id: z.string().nullable(),
});

export type FlashSaleTicket = z.infer<typeof FlashSaleTicketSchema>;
