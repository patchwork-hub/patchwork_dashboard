# Environment variables

Copy `.env.sample` to `.env` and replace every placeholder before production use. Keep `.env` out of source control. This page documents the variables supplied by the sample file; the application may also pass service-specific variables into provisioned community instances.

| Group | Variables | Required | Consumer and dependency |
| --- | --- | --- | --- |
| Rails runtime | `RAILS_ENV` (default `development`), `RAILS_SERVE_STATIC_FILES` (default `true`), `PORT` (sample value `3001`), `EXTERNAL_PORT` (sample value `3001`) | Yes | Rails and Docker Compose. `PORT` and `EXTERNAL_PORT` are deployment values; `.env.sample` sets both to `3001` for the documented Compose path. |
| Mastodon identity | `LOCAL_DOMAIN`, `MASTODON_INSTANCE_URL` | Yes | Serializers and outbound Mastodon REST API services. Use an HTTPS URL for `MASTODON_INSTANCE_URL`. |
| Mastodon application | `MASTODON_APPLICATION_TOKEN`, `MASTODON_CLIENT_ID`, `MASTODON_CLIENT_SECRET` | Yes | Dashboard calls to the host Mastodon API. Treat all as secrets. The documented scopes are `read`, `profile`, `write`, `follow`, and `push`. |
| Shared PostgreSQL | `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`, `DB_PORT` (default `5432`), `DB_POOL` (default `24`) | Yes | Active Record connection to the Mastodon database. This is a **shared database** dependency. |
| Redis and Sidekiq | `REDIS_HOST`, `REDIS_PORT` (default `6379`), `REDIS_PASSWORD`, `REDIS_NAMESPACE` (default `dashboard`), `REDIS_DB`, `SIDEKIQ_REDIS_DB` | Yes, except `SIDEKIQ_REDIS_DB` | Redis cache and Sidekiq. When `SIDEKIQ_REDIS_DB` is absent, the initializer falls back to `REDIS_DB`. |
| Dashboard features | `CHANNELS_ENABLED`, `CHANNEL_POST_HASHTAG_ENABLED`, `NEWSMAST_POST_HASHTAG_ENABLED` | Conditional, default `false` | Enables respective channel UI behavior. These do not install the gem-side runtime behavior. |
| Patchwork Hub | `PATCHWORK_HUB_URL` (sample default `https://hub.patchwork.online`) | Conditional | **Patchwork Hub API** endpoint for settings and keyword-filter synchronization. API credentials are managed in the Dashboard API-key interface. |
| Master administrator | `MASTER_ADMIN_USERNAME`, `MASTER_ADMIN_EMAIL`, `MASTER_ADMIN_PASSWORD` | Yes for seeded administrative login | Seed/application administration. Use a unique account identity that does not collide with a Mastodon account. Password is secret. |
| Object storage | `S3_ENABLED` (default `false`), `S3_REGION`, `S3_BUCKET`, `S3_ALIAS_HOST`, `S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Production: S3 settings required | Production config sets Paperclip storage to S3 unconditionally; `S3_ENABLED` is not used there as a runtime gate. Configure valid S3-compatible endpoint, bucket, region, and credentials. Access key and secret are secrets. |
| Bluesky and DNS | `USE_LOCAL_DOMAIN` (sample default `true`), `DNS_PROVIDER`, `AWS_ACCESS_DNS_RESOLVE_ID`, `AWS_SECRET_DNS_RESOLVE_KEY`, `AWS_DNS_REGION` | Conditional | Bridgy Fed/DNS provisioning. Route53 is the provider documented in `.env.sample`; see [DNS provider contribution guide](../../CONTRIBUTING_DNS_PROVIDERS.md). |
| API and Rails secrets | `STATIC_TOKEN`, `SECRET_KEY_BASE` | Yes | API bearer-token validation for selected endpoints and Rails session/cryptographic security. Generate with `openssl rand -hex 64` and `rails secret`, respectively. |

## Format and handling

Use plain `KEY=value` syntax with no shell annotations. In particular, make `SIDEKIQ_REDIS_DB` either a number or omit it; the optionality belongs in the comment, not in the value. Quote values only where dotenv syntax requires it. Keep credentials in a secret store or protected environment file, never in browser clients or logs.

## Ownership

The Dashboard owns its own runtime configuration. The host Mastodon deployment owns its database, Redis availability, and Mastodon application registration. The Newsmast Mastodon gem owns gem-specific runtime configuration; consult its configuration documentation for behavior not represented by this application.

For storage specifically, do not treat `S3_ENABLED=false` as a production disable switch: production still reads the S3 credential and endpoint variables for Paperclip storage.