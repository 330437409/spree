// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipBannerAreaSchema = z.object({
  area_rem: z.string(),
  link: z.string(),
  name: z.string().nullable(),
});

export type MembershipBannerArea = z.infer<typeof MembershipBannerAreaSchema>;
