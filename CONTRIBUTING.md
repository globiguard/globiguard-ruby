# Contributing

GlobiGuard Ruby SDK changes should avoid gem runtime dependencies unless a security review accepts a specific exception.

## Validate locally

```bash
ruby -c lib/globiguard.rb
ruby test/smoke_test.rb
gem build globiguard.gemspec
```

Examples must use placeholder secrets only and webhook handlers must pass raw request body bytes into verification.

