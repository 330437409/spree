// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipSavingRowSchema = z.object({
  title: z.string().nullable(),
  content: z.string().nullable(),
});

export type MembershipSavingRow = z.infer<typeof MembershipSavingRowSchema>;
