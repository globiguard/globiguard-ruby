# globiguard-ruby

Official dependency-minimal Ruby SDK for GlobiGuard.

The package has no gem runtime dependencies. It uses Ruby stdlib for HTTP, HMAC, JSON, URL handling, and OpenSSL-backed Ed25519 entitlement verification where the installed Ruby/OpenSSL build supports Ed25519.

## Install

```bash
gem install globiguard
```

## Server client

```ruby
require "globiguard"

client = GlobiGuard::Client.server(
  environment: "sandbox",
  services: { "controlPlane" => "https://api.globiguard.com" },
  credential: GlobiGuard::Credential.secret("proj_example", "ggsk_example_replace_me", "sandbox")
)

decision = client.governed_actions.authorize_action_or_throw(
  actionType: "refund",
  actor: { id: "user_123" },
  target: { id: "order_456" }
)
```

## Webhooks

Pass the exact raw request body string. Do not parse and re-serialize JSON before verification.

```ruby
result = GlobiGuard::TrustWebhook.verify(headers, raw_body, "whsec_example_replace_me")
raise result[:error] unless result[:ok]
```

## Development

```bash
ruby -c lib/globiguard.rb
ruby test/smoke_test.rb
gem build globiguard.gemspec
```
