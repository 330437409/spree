// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerDecisionSchema = z.object({
  matched: z.boolean(),
  match_type: z.string().nullable(),
  polygon_result: z.string().nullable(),
  stale: z.boolean(),
  distance_km: z.number().nullable(),
  seller: z.any(),
  administrative_division: z.any(),
  warehouse: z.any(),
});

export type SellerDecision = z.infer<typeof SellerDecisionSchema>;
