// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipSchema = z.object({
  id: z.string(),
  status: z.string(),
  starts_at: z.string().nullable(),
  ends_at: z.string().nullable(),
});

export type Membership = z.infer<typeof MembershipSchema>;
