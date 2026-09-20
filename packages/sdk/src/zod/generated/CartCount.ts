// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CartCountSchema = z.object({
  id: z.string(),
  total_quantity: z.number(),
  selected_quantity: z.number(),
});

export type CartCount = z.infer<typeof CartCountSchema>;
