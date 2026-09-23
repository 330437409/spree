// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MemberCentreSchema = z.object({
  id: z.string(),
  tier: z.record(z.string(), z.unknown()).nullable(),
  rights_total: z.number(),
  sections: z.any(),
});

export type MemberCentre = z.infer<typeof MemberCentreSchema>;
