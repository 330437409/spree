// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PromotionCandidateSchema = z.object({
  id: z.string(),
  promotion_id: z.string(),
  code: z.string().nullable(),
  name: z.string().nullable(),
  description: z.string().nullable(),
  amount: z.string(),
  display_amount: z.string(),
});

export type PromotionCandidate = z.infer<typeof PromotionCandidateSchema>;
