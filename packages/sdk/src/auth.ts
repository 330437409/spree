import type { LoginResult, RegistrationRequired } from './types'

/**
 * Narrows a redirect login result to the registration step.
 *
 * A provider that returns no email (WeChat, Douyin) authenticates the shopper
 * without giving the store an address to create an account from. The API then
 * answers `{ status: 'registration_required', registration_token }`, and
 * `auth.completeRegistration` finishes the job with an address the shopper
 * supplies — so no account is ever created with one that cannot receive mail.
 *
 * @example
 * const result = await client.auth.loginWithRedirect({ provider: 'wechat', code, state })
 * if (isRegistrationRequired(result)) {
 *   const tokens = await client.auth.completeRegistration({
 *     registration_token: result.registration_token,
 *     email,
 *   })
 * }
 */
export function isRegistrationRequired(result: LoginResult): result is RegistrationRequired {
  return 'status' in result && result.status === 'registration_required'
}
