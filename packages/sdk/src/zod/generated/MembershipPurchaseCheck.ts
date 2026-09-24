// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipPurchaseCheckSchema = z.object({
  kind: z.string(),
  tier_name: z.string().nullable(),
  held_until: z.string().nullable(),
});

export type MembershipPurchaseCheck = z.infer<typeof MembershipPurchaseCheckSchema>;
