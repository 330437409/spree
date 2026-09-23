// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ScenarioPaymentSessionSchema = z.object({
  external_id: z.string(),
  status: z.string(),
  expires_at: z.string().nullable(),
  external_data: z.record(z.string(), z.unknown()).nullable(),
});

export type ScenarioPaymentSession = z.infer<typeof ScenarioPaymentSessionSchema>;
