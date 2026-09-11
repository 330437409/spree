# Spree Social Auth

Social login for Spree Commerce, starting with the providers a store selling into
mainland China needs: **WeChat Open Platform** and, following it, Douyin — plus the
Western providers that sit on the same OAuth 2.0 flow.

The gem adds no identity model and no session mechanism. A provider is a strategy in
Spree's authentication registry, an identity is a `Spree::UserIdentity`, an account is
created by `Spree.customer_create_workflow`, and the login ends in the same JWT and
refresh token pair a password login issues. The design is written up in
[`docs/plans/6.0-social-login.md`](../../../docs/plans/6.0-social-login.md).

## Installation

```ruby
gem 'spree_social_auth'
```

```bash
bundle install
```

The gem registers its providers when the application boots; there is nothing to
generate and no migration beyond the ones Spree already ships.

## Configuring a provider

Each provider's credentials live in an `Integration`, one per store, edited on the
dashboard's **Settings → Integrations → Authentication** page:

| Field | What it is |
|---|---|
| Client Id | The provider's application identifier — WeChat's AppID, Douyin's client key |
| Client Secret | The matching secret |
| Redirect Uri | The URL the provider redirects back to, registered in the provider's console |
| Trust Unverified Email | Off by default. Only for a provider whose directory owns the addresses it issues |

The callback URL must also sit under an origin listed on **Settings → Allowed
Origins**, and it ends in the provider key — `/account/callback/wechat`,
`/account/callback/douyin`, `/account/callback/google`.

A provider appears on a storefront's login page only while its integration is active
for that store.

## Providers

| Key | Provider | Returns an email |
|---|---|---|
| `wechat` | WeChat Open Platform website application | no — the shopper is asked for one |
| `douyin` | Douyin Open Platform website application | no — the shopper is asked for one |
| `google` | Google | yes, marked verified |

WeChat, Douyin, QQ, Weibo and Alipay authenticate a shopper without returning an email.
Nothing is created in that case: the login answers `registration_required` and the
storefront collects an address, so no account is ever created with an address that
cannot receive mail.

## Before you start

Every provider requires an approved application, the callback URL registered with it,
and — for WeChat — a website application whose site carries an ICP备案号. Those
approvals, not the integration, are the slow part.

The merchant-facing guides ship with the documentation site:
[social login](https://docs.spreecommerce.org/integrations/authentication/social-login),
[WeChat](https://docs.spreecommerce.org/integrations/authentication/wechat),
[Douyin](https://docs.spreecommerce.org/integrations/authentication/douyin) and
[Google](https://docs.spreecommerce.org/integrations/authentication/google).

## Development

```bash
bundle install
bundle exec rake test_app   # once
bundle exec rspec
```
