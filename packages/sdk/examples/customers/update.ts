import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// The profile a storefront shows back: a nickname, how the customer describes
// themselves, a birthday and the city they usually buy from. An avatar is an
// upload — send the signed id the direct upload answered with.
const customer = await client.customer.update(
  {
    first_name: 'John',
    last_name: 'Doe',
    nickname: 'AdaBear',
    gender: 'female',
    birthday: '1990-05-01',
    city: 'Suzhou',
    metadata: { preferred_contact: 'email' },
  },
  {
    token: '<token>',
  },
)

// endregion:example

export { customer }
