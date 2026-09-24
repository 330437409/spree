// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MembershipSavingRowSchema } from './MembershipSavingRow';

export const MembershipSavingSchema = z.object({
  rows: z.array(MembershipSavingRowSchema),
  rules: z.string().nullable(),
  month_amount: z.string().nullable(),
});

export type MembershipSaving = z.infer<typeof MembershipSavingSchema>;
