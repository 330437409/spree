// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipTierSchema = z.object({
  id: z.string(),
  name: z.string(),
  rank: z.number(),
  threshold: z.string().nullable(),
  validity_days: z.number().nullable(),
  rights_total: z.number(),
});

export type MembershipTier = z.infer<typeof MembershipTierSchema>;
