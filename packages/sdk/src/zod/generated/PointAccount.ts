// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PointAccountSchema = z.object({
  id: z.string().nullable(),
  kind: z.string(),
  balance: z.number(),
  lifetime_earned: z.number(),
  expiring_total: z.number().nullable(),
  expires_at: z.string().nullable(),
  earn_rate: z.string().nullable(),
  redeem_rate: z.string().nullable(),
});

export type PointAccount = z.infer<typeof PointAccountSchema>;
