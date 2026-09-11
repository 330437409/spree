---
'@spree/sdk': minor
---

Social login reaches the Store SDK.

- `auth.providers()` — the providers a store has configured, so a login page can render itself: the password form when `email` is registered, a button per redirect provider. `requires_email` warns that the provider returns no email.
- `auth.loginWithRedirect({ provider, code, state, redirect_uri })` — completes the login a provider's browser redirect started. The API exchanges the code, because only the API holds the client secret.
- `auth.completeRegistration({ registration_token, email, ... })` — creates the account with an address the shopper supplies, for the providers that return none (WeChat, Douyin).
- `isRegistrationRequired(result)` narrows a redirect login result to that registration step.

`auth.login` is unchanged: it still returns tokens for email/password and for custom providers that post their own credentials.
