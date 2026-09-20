// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreShareSchema = z.object({
  title: z.string().nullable(),
  subtitle: z.string().nullable(),
  image_url: z.string().nullable(),
  path: z.string(),
  scene: z.string().nullable(),
  qrcode_url: z.string().nullable(),
  poster_url: z.string().nullable(),
});

export type StoreShare = z.infer<typeof StoreShareSchema>;
