// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipCardSummarySchema = z.object({
  id: z.string(),
  tier: z.record(z.string(), z.unknown()).nullable(),
  status: z.string(),
  activates_before: z.string().nullable(),
});

export type MembershipCardSummary = z.infer<typeof MembershipCardSummarySchema>;
