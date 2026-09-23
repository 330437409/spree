// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentPinSchema = z.object({
  set: z.boolean(),
  required: z.boolean(),
});

export type PaymentPin = z.infer<typeof PaymentPinSchema>;
