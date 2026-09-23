// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const VerificationCheckSchema = z.object({
  phone: z.string(),
  verified_at: z.string().nullable(),
  expires_at: z.string(),
});

export type VerificationCheck = z.infer<typeof VerificationCheckSchema>;
