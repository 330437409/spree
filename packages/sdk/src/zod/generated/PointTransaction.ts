// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PointTransactionSchema = z.object({
  id: z.string(),
  kind: z.string(),
  label: z.string(),
  amount: z.string(),
  balance_after: z.string().nullable(),
  occurred_at: z.string(),
});

export type PointTransaction = z.infer<typeof PointTransactionSchema>;
