// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipRightSchema = z.object({
  id: z.string(),
  type: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  badge: z.string().nullable(),
  image_url: z.string().nullable(),
  published: z.boolean(),
  tier: z.record(z.string(), z.unknown()).nullable(),
});

export type MembershipRight = z.infer<typeof MembershipRightSchema>;
