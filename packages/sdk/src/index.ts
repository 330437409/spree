// Main client

export type { RequestFn, RequestOptions, RetryConfig } from '@spree/sdk-core'
// Request infrastructure (re-export from sdk-core)
export { SpreeError } from '@spree/sdk-core'
// Social login: narrows a redirect login to the registration step
export { isRegistrationRequired } from './auth'
export type { Client, ClientConfig } from './client'
export { createClient } from './client'
// Store client class (for advanced use / subclassing)
export { StoreClient } from './store-client'

// All types
export * from './types'
