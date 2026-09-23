// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdministrativeDivisionSchema } from './AdministrativeDivision';
import { SellerSchema } from './Seller';
import { SiteSchema } from './Site';

export const SellerDecisionSchema = z.object({
  matched: z.boolean(),
  match_type: z.string().nullable(),
  polygon_result: z.string().nullable(),
  stale: z.boolean(),
  distance_km: z.number().nullable(),
  seller: SellerSchema.nullable(),
  administrative_division: AdministrativeDivisionSchema.nullable(),
  warehouse: SiteSchema.nullable(),
});

export type SellerDecision = z.infer<typeof SellerDecisionSchema>;
