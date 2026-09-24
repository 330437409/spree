// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MemberDaySchema = z.object({
  name: z.string().nullable(),
  today: z.boolean(),
  line: z.string().nullable(),
  times: z.number(),
  minimum_amount: z.string().nullable(),
  qualifying_kinds: z.array(z.string()),
  rights_red: z.boolean(),
  rights_red_money: z.string().nullable(),
  rule: z.string().nullable(),
  share_title: z.string().nullable(),
  share_icon: z.string().nullable(),
});

export type MemberDay = z.infer<typeof MemberDaySchema>;
