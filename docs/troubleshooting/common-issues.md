# Common issues

## PostgreSQL or Redis connection failures

Confirm `DB_*` and `REDIS_*` values point to services reachable from the Dashboard container/process. For Docker, inspect `docker compose logs app` and test the configured database connection with `docker compose exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"`. The Dashboard requires access to the host Mastodon database and Redis; it does not create substitutes.

## Mastodon credentials or scopes

Confirm `MASTODON_INSTANCE_URL` is the correct HTTPS base URL and that the configured application token/client credentials have the required scopes. Check application logs for HTTP failures, but redact bearer tokens, client secrets, and API keys from reports.

## Version or schema mismatch

Run the migrations owned by the deployed repository after updating it. The Dashboard and Newsmast Mastodon each own their migrations; apply the compatible host/gem update procedure separately. Do not infer cross-repository migration order from a missing feature.

## Filter refresh or enforcement

Check that the relevant `content_filters` or `spam_filters` setting exists and is enabled, `PATCHWORK_HUB_URL` is reachable, and a Dashboard API key is stored. Check Sidekiq/application logs for `KeywordFiltersJob`. Dashboard refreshes filter configuration; Newsmast Mastodon owns supported enforcement and cache behavior, so also verify its Redis/worker health.

## Channel automation and feeds

Verify channel administrators/boost bots are active, Mastodon credentials are valid, and the compatible Newsmast Mastodon behavior is installed for custom feeds or reblog automation. A Dashboard channel record alone does not create a gem-backed feed.

## Bluesky, DNS, relay, or storage failures

Verify `USE_LOCAL_DOMAIN`, the selected provider credentials, external-service availability, and DNS propagation before retrying bridge provisioning. For storage, verify S3 endpoint/bucket/region credentials. For relay failures, check the external relay endpoint and Mastodon authorization. Avoid logging secrets.

## Docker health and ports

The Compose service is `app`. Check `docker compose ps`, `docker compose logs app`, and the health endpoint. The supplied health check uses `EXTERNAL_PORT` inside the container while Rails listens on `3001`; retain the default port or validate a corrected override before changing it.

See [Docker installation](../../DOCKER_INSTALLATION.md) and [environment variables](../configuration/environment-variables.md) for the canonical commands and settings.