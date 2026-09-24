// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MembershipBannerAreaSchema } from './MembershipBannerArea';

export const MembershipBannerSchema = z.object({
  id: z.string(),
  name: z.string().nullable(),
  pic: z.string(),
  areas: z.array(MembershipBannerAreaSchema),
});

export type MembershipBanner = z.infer<typeof MembershipBannerSchema>;
