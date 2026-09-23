// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ScenarioOrderSchema = z.object({
  id: z.string(),
  kind: z.string(),
  status: z.string(),
  payment_channel: z.string(),
  amount: z.string(),
  currency: z.string(),
  payload: z.record(z.string(), z.unknown()).nullable(),
  payment_session: z.record(z.string(), z.unknown()).nullable(),
});

export type ScenarioOrder = z.infer<typeof ScenarioOrderSchema>;
