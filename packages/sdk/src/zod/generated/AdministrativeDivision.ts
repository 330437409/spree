// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdministrativeDivisionSchema = z.object({
  id: z.string(),
  code: z.string(),
  name: z.string(),
  level: z.string(),
  first_pinyin: z.string(),
  has_children: z.boolean(),
});

export type AdministrativeDivision = z.infer<typeof AdministrativeDivisionSchema>;
