// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipCardTierSchema = z.object({
  id: z.string(),
  name: z.string(),
  rank: z.number(),
});

export type MembershipCardTier = z.infer<typeof MembershipCardTierSchema>;
