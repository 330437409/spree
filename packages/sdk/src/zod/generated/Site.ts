// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PolicySchema } from './Policy';

export const SiteSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  about: z.string(),
  about_html: z.string(),
  logo_url: z.string().nullable(),
  square_logo_url: z.string().nullable(),
  cover_photo_url: z.string().nullable(),
  policies: z.array(PolicySchema).optional(),
  site_svip: z.boolean(),
  operator: z.any(),
});

export type Site = z.infer<typeof SiteSchema>;
