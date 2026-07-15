# Channels

> **Dependency:** Newsmast Dashboard is **Required** to configure channels. Newsmast Mastodon is **Required** for gem-backed custom feeds and related runtime behavior. Mechanisms: **shared database**, **Mastodon REST API**, **Newsmast custom API**, and **Redis/Sidekiq**.

## Capabilities

The Dashboard manages channels (internally communities), including names, slugs, branding, descriptions, visibility, content type, rules, links, additional information, and collections. Starter packs are served separately from repository JSON by the channel API. Operators can configure hashtags and post hashtags, contributors, muted contributors, post types, channel administrators, and active boost bots.

The browser workflow is a multi-step channel creation/edit flow at `/channels`: define basic channel data, content type and hashtags, contributors, administrators, and presentation details. Existing channels can be recovered or upgraded through their member routes. The exact available fields vary by channel type and enabled feature flags.

## Operations and permissions

Dashboard browser access requires an authenticated user and Pundit authorization. Creating or updating a community administrator can trigger the Dashboard's Mastodon account-facing service. Boost bots are represented by active community-administrator records and are used by supported downstream behavior.

Use the channel API for application integrations:

- `GET/POST /api/v1/channels` and member routes manage channel records.
- Nested `community_filter_keywords`, `community_hashtags`, and `community_post_types` routes manage related data.
- Discovery routes include `channel_feeds`, `newsmast_channels`, `starter_packs_channels`, and `starter_packs_detail`.

See [Dashboard API](../api/dashboard-api.md) for the Dashboard credential model.

## Cross-component behavior

The Dashboard owns the shared records. Newsmast Mastodon reads supported channel and community-admin data to expose custom feeds and channel-related automation. Dashboard services use the Mastodon REST API for operations such as account search, follows, hashtags, posting, and reblogging. A missing or incompatible gem leaves configuration data in place but does not provide gem-backed feed/automation behavior.

Relay support is an external-service integration and depends on valid Mastodon credentials plus the relay endpoint. It is not a replacement for the gem's own relay configuration.

## Related documentation

- [Content filters](content-filters.md)
- [Integrations](integrations.md)
- Newsmast Mastodon public [custom feeds guide](https://github.com/TheNewsmastFoundation/documentation/blob/main/newsmast-mastodon/features_custom_feeds.md)