// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreOrderCancellationReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type StoreOrderCancellationReason = z.infer<typeof StoreOrderCancellationReasonSchema>;
