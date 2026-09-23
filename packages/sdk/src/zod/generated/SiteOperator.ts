// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SiteOperatorSchema = z.object({
  id: z.string(),
  site_name: z.string(),
  company_name: z.string().nullable(),
  image_url: z.string().nullable(),
  business_model: z.string().nullable(),
});

export type SiteOperator = z.infer<typeof SiteOperatorSchema>;
