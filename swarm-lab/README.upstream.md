# Newsmast Dashboard

Newsmast Dashboard is the administrative Rails application in this repository (`patchwork_dashboard`). It works alongside a host Mastodon server, the `newsmast_mastodon` gem, and optionally Patchwork Hub. It is not a gem dependency of `newsmast_mastodon`: the components cooperate through a shared database, HTTP APIs, OAuth/Doorkeeper, and Redis/Sidekiq.

## Terminology

- **Newsmast Dashboard** is the public product name.
- **Patchwork Dashboard** and `patchwork_dashboard` identify this repository, application, container image, and implementation names.
- **Patchwork Hub** is an optional external service used for server-setting and keyword-filter synchronization.
- **Newsmast Mastodon** is the gem installed in the host Mastodon application; it consumes shared records and provides custom Mastodon behavior.

## Compatibility and prerequisites

Run the Dashboard against a compatible, already-running Mastodon installation. It requires network access to the Mastodon REST API, the Mastodon PostgreSQL database, and Redis. Production deployments also need a reverse proxy/TLS configuration outside this Compose file.

See [environment variables](docs/configuration/environment-variables.md) for the required connection and credential values. Use [DOCKER_INSTALLATION.md](DOCKER_INSTALLATION.md) for the canonical container procedure.

## Installation and updates

- Source setup: copy `.env.sample` to `.env` and configure values, run `bin/setup`, then start Rails.
- Docker setup: follow [DOCKER_INSTALLATION.md](DOCKER_INSTALLATION.md).
- Update source deployments with the repository's normal dependency and migration workflow. Update Docker deployments with `docker compose pull`, `docker compose up -d`, then `docker compose exec app bundle exec rails db:migrate` when migrations are supplied.

## Feature index

- [Channels](docs/features/channels.md): channel data, contributors, hashtags, collections, boost bots, relays, and recovery.
- [Content filters](docs/features/content-filters.md): server and community filter data, Hub synchronization, and cache refresh.
- [Server settings](docs/features/server-settings.md): feature settings, branding, and setting synchronization.
- [Administration](docs/features/administration.md): accounts, roles, administrators, wait lists, API keys, exports, and Sidekiq access.
- [Integrations](docs/features/integrations.md): Mastodon, Patchwork Hub, Bluesky/Bridgy Fed, DNS, relay, and object storage contracts.

## Dependency matrix

| Capability | Configuration owner | Runtime owner | Dependency mechanism | Without the other component |
| --- | --- | --- | --- | --- |
| Channels and collections | Dashboard | Newsmast Mastodon | shared database and Newsmast custom API | Definitions can be managed, but gem-backed feeds are unavailable |
| Starter packs | Dashboard | Dashboard | repository JSON and Dashboard API | No Newsmast Mastodon dependency |
| Channel reblogging | Dashboard | Newsmast Mastodon | shared database, Mastodon REST API, Redis/Sidekiq | Boost-bot configuration remains data only |
| Global and community filters | Dashboard | Newsmast Mastodon | shared database and Redis/Sidekiq | Filter definitions can be managed; gem enforcement is unavailable |
| Search, long-post, and local-only settings | Dashboard | Newsmast Mastodon/Mastodon | shared database and Patchwork Hub API | Dashboard records remain; host behavior depends on its installed components |
| Account deletion and relay APIs | Dashboard | Newsmast Mastodon/Mastodon | Newsmast custom API and Mastodon REST API | Relevant external operation is unavailable |
| Bluesky bridge | Dashboard | Dashboard jobs and external service | Mastodon REST API, external service, DNS provider | The bridge cannot be provisioned without its external dependencies |
| Email branding | Dashboard | host Mastodon/Newsmast Mastodon | shared database | Branding data is not applied without host support |
| Gem-only APIs and integrations | Newsmast Mastodon | Newsmast Mastodon | gem configuration | Dashboard is not required |

## Technical references

- [Configuration reference](docs/configuration/environment-variables.md)
- [Mastodon integration architecture](docs/architecture/mastodon-integration.md)
- [Dashboard API reference](docs/api/dashboard-api.md)
- [Troubleshooting](docs/troubleshooting/common-issues.md)
- [DNS provider contribution guide](CONTRIBUTING_DNS_PROVIDERS.md)

## Development

```bash
cp .env.sample .env
$EDITOR .env
bin/setup
bundle exec rails server
bundle exec rails test
```

Use `bundle exec rubocop` for style checks. The application also exposes Sidekiq Web at `/sidekiq` to authenticated users with `manage_sidekiq` permission or master-admin status.

Internal teams should follow the [branching and merging workflow](docs/development/branching-and-merging.md).

## Maintainer checklist

- Update `.env.sample` and the [configuration reference](docs/configuration/environment-variables.md) together.
- Update [Dashboard API documentation](docs/api/dashboard-api.md) when supported routes change.
- Update Dashboard and Newsmast Mastodon dependency notes when a shared contract changes.
- Review the public documentation summaries as part of releases.

## Support, contributing, and license

Report issues and contribute through this repository. Read the [DNS provider contribution guide](CONTRIBUTING_DNS_PROVIDERS.md) when extending DNS support, and review the [LICENSE](LICENSE). For installation or partnership support, contact `support@newsmastfoundation.org`.