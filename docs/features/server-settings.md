# Server settings

> **Dependency:** Newsmast Dashboard is **Required** to manage Dashboard server-setting records. Newsmast Mastodon or host Mastodon support is **Required** for settings that change host behavior. Mechanisms: **shared database**, **Patchwork Hub API**, and **Redis/Sidekiq**.

## Settings taxonomy

The Dashboard maintains parent groups and child settings. The current display taxonomy includes spam block, content moderation, federation, local features, user management, plug-ins, Bluesky bridge, and email branding. Child settings include automatic search opt-in, local-only posts, long posts, content/spam filters, Bluesky bridge automation, and other UI-visible options. Labels and descriptions are defined in `config/server_settings.yml`; stable keys are persisted in `server_settings`.

## Synchronization and jobs

Only a changed child setting is sent to Patchwork Hub after commit. `SyncSettingService` posts the parent name and changed child name/value/position to `/api/v1/server_settings/upsert` using the first Dashboard API key record. Root settings are not synchronized by this callback.

Changing `search_opt_out` enqueues `UpdateAccountsDiscoverabilityJob`. Enabling `bluesky_bridge_auto` enqueues `BlueskyBridgeEnabledJob`. Content/spam settings invoke the filter job described in [content filters](content-filters.md).

## Branding and enforcement

The Dashboard provides server-setting and branding administration routes. It owns the setting data; application of search, long-post, local-only, email-branding, and similar behavior depends on the compatible host Mastodon and Newsmast Mastodon components that consume it. Do not assume a Dashboard toggle alone changes a host feature.

## Related documentation

- [Configuration](../configuration/environment-variables.md)
- [Architecture](../architecture/mastodon-integration.md)
- Newsmast Mastodon public [posts guide](https://github.com/TheNewsmastFoundation/documentation/blob/main/newsmast-mastodon/features_posts.md)