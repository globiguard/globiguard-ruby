# GlobiGuard Ruby SDK - Development Guide

## CI/CD Pipeline Overview

This repository uses GitHub Actions for automated testing, building, and publishing.

### Workflows

#### 1. **Test & Lint** (`test.yml`)
- **Triggers:** Every push to `main`/`develop`, and on all pull requests
- **What it does:**
  - Tests across Ruby 3.1, 3.2, and 3.3
  - Validates Ruby syntax
  - Runs tests via Minitest/Rake
- **Status check:** ✅ Must pass before merging to `main`

#### 2. **Build & Package** (`build.yml`)
- **Triggers:** Every push to `main`/`develop`, and on all pull requests
- **What it does:**
  - Validates gemspec
  - Builds gem file
  - Verifies gem contents
  - Uploads to GitHub Artifacts
- **Purpose:** Verify package structure before publish

#### 3. **Publish** (`publish.yml`)
- **Triggers:** When a git tag matching `v*.*.*` is pushed
- **What it does:**
  - Builds gem
  - Publishes to RubyGems
  - Creates GitHub Release
- **Requirements:** `GEM_HOST_API_KEY` secret configured
- **Usage:**
  ```bash
  git tag v0.1.0
  git push origin v0.1.0
  ```

#### 4. **Security Scan** (`security.yml`)
- **Triggers:** Every push to `main`/`develop`, weekly on Sunday
- **What it does:**
  - Runs bundler-audit for vulnerabilities
  - Runs Brakeman for security issues
  - Runs RuboCop for code quality
- **Purpose:** Continuous security and quality monitoring

### Branch Protection

The `main` branch is protected with:
- ✅ Require 1 pull request review before merging
- ✅ Require all status checks to pass
- ✅ Require branches to be up to date before merging
- ✅ Dismiss stale pull request approvals on new commits
- ✅ Require code owner reviews
- ❌ Force pushes disabled
- ❌ Deletions disabled

### Versioning Strategy

We use **Semantic Versioning** (major.minor.patch):

- **0.1.0** → Initial release
- **0.1.1** → Patch fix
- **0.2.0** → Minor feature
- **1.0.0** → Major release (breaking changes)

Update version in `globiguard.gemspec`:
```ruby
spec.version = "0.1.0"
```

### Publishing Workflow

```bash
# 1. Make changes on a feature branch
git checkout -b feat/new-feature
git commit -m "feat: new feature"

# 2. Update version if needed
# Edit globiguard.gemspec: spec.version = "0.2.0"
git commit -m "bump: version to 0.2.0"

# 3. Push and create PR
git push origin feat/new-feature

# 4. Review, merge to main

# 5. Tag release
git tag v0.1.0
git push origin v0.1.0

# 6. Watch CI/CD publish to RubyGems
# gem install globiguard
```

### Development Cycle

1. **Create feature branch:** `git checkout -b feature/name main`
2. **Make changes:** Edit code, test locally
3. **Run tests locally:** `bundle exec rake test`
4. **Commit:** `git commit -m "feat: description"`
5. **Push:** `git push origin feature/name`
6. **Create PR:** Open GitHub pull request to `main`
7. **Review:** Automated tests and code review
8. **Merge:** Merge PR to `main`
9. **Publish (optional):** Update version and tag

### Local Testing

```bash
# Install dependencies
bundle install

# Validate gemspec
gem specification globiguard.gemspec

# Run tests
bundle exec rake test

# Or run directly
ruby -Ilib test/smoke_test.rb

# Lint Ruby
ruby -c lib/globiguard.rb

# Run RuboCop
bundle exec rubocop lib/ test/ || true

# Build gem locally
gem build globiguard.gemspec
```

### Code Owners

Code ownership is defined in `.github/CODEOWNERS`:
- All files: `@globi-explore/maintainers`
- PRs require approval from code owners before merge

### Repository Configuration

- **Default branch:** `main`
- **Discussions:** Enabled (for Q&A)
- **Releases:** Auto-generated from tags
- **Topics:** `globiguard`, `sdk`, `governance`, `ruby`, `rubygems`
- **Visibility:** Public
- **Ruby version:** 3.1+
- **License:** Apache-2.0

## Troubleshooting

**Bundle install fails?**
- Update bundler: `gem update bundler`
- Clear cache: `bundle cache --no-prune`
- Check Ruby version: `ruby -v`

**Tests fail?**
- Run with verbose: `bundle exec rake test VERBOSE=1`
- Check Ruby version compatibility
- Ensure all dependencies installed

**RubyGems publish fails?**
- Verify gem name isn't taken
- Check API key is valid
- Ensure version format matches

## Questions?

See main repository README or GitHub Discussions for Q&A.
