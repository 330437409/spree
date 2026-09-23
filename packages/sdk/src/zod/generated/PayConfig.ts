// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PayConfigSchema = z.object({
  channels: z.array(z.any()),
  kinds: z.array(z.any()),
  payment_pin: z.boolean(),
});

export type PayConfig = z.infer<typeof PayConfigSchema>;
