// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { CustomerGroupSchema } from './CustomerGroup';
import { NewsletterSubscriberSchema } from './NewsletterSubscriber';

export const CustomerSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  phone: z.string().nullable(),
  accepts_email_marketing: z.boolean(),
  nickname: z.string().nullable(),
  gender: z.string().nullable(),
  city: z.string().nullable(),
  email_marketing_consent_updated_at: z.string().nullable(),
  birthday: z.string().nullable(),
  avatar_url: z.string().nullable(),
  orders_count: z.number(),
  full_name: z.string(),
  available_store_credit_total: z.string(),
  display_available_store_credit_total: z.string(),
  addresses: z.array(AddressSchema),
  default_billing_address: AddressSchema.nullable(),
  default_shipping_address: AddressSchema.nullable(),
  newsletter_subscriber: NewsletterSubscriberSchema.nullable(),
  customer_groups: z.array(CustomerGroupSchema),
});

export type Customer = z.infer<typeof CustomerSchema>;
