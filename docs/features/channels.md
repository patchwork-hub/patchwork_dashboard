# Channels

> **Dependency:** Newsmast Dashboard is **Required** to configure channels. Newsmast Mastodon is **Required** for gem-backed custom feeds and related runtime behavior. Mechanisms: **shared database**, **Mastodon REST API**, **Newsmast custom API**, and **Redis/Sidekiq**.

## Capabilities

The Dashboard manages channels (internally communities), including names, slugs, branding, descriptions, visibility, content type, rules, links, additional information, and collections. Starter packs are managed at `/starter_packs` and served from `patchwork_starter_packs` by the channel API. Operators can configure hashtags and post hashtags, contributors, muted contributors, post types, channel administrators, and active boost bots.

The browser workflow is a multi-step channel creation/edit flow at `/channels`: define basic channel data, content type and hashtags, contributors, administrators, and presentation details. Existing channels can be recovered or upgraded through their member routes. The exact available fields vary by channel type and enabled feature flags.

## Operations and permissions

Dashboard browser access requires an authenticated user and Pundit authorization. Creating or updating a community administrator can trigger the Dashboard's Mastodon account-facing service. Boost bots are represented by active community-administrator records and are used by supported downstream behavior.

Use the channel API for application integrations:

- `GET/POST /api/v1/channels` and member routes manage channel records.
- Nested `community_filter_keywords`, `community_hashtags`, and `community_post_types` routes manage related data.
- Discovery routes include `channel_feeds`, `newsmast_channels`, `starter_packs_channels`, and `starter_packs_detail`.

See [Dashboard API](../api/dashboard-api.md) for the Dashboard credential model.

## Starter packs

Master administrators and users with `manage_starter_packs` can create, edit, delete and order packs, assign a creator through local/remote account search, and add, remove and order accounts. The creator is independent of the logged-in dashboard user. Account search uses the configured Mastodon instance and the dashboard user's access token; it does not follow accounts.

The public list endpoint returns `{ data: [...] }`; detail returns `{ channel: {...}, followers: [...] }`. `starter_pack_source` selects a normalized instance name and defaults to `twt`. Unknown sources return an empty list; detail IDs are scoped to the source. There is no JSON fallback. Database pack IDs replace legacy JSON IDs, so clients must refresh their lists. The engine's separate file-backed endpoints are unchanged.

Preview existing data with `bin/rails starter_packs:import SOURCE=findout DRY_RUN=true`. Import with `bin/rails starter_packs:import SOURCE=findout USER_ID=123`, replacing `123` with a local Mastodon user ID, not an account ID. Omit `SOURCE` to process every data folder; use `DATA_DIR=/path/to/config/data` for engine data, including Leicester. Each entry in `starter_pack_list.json` loads `starter_pack_<id>.json` using its listed ID, not its position in the list. Only listed packs are imported. Import replaces pack membership in file order, deduplicates accounts, and is repeatable by instance and title. New packs receive the next available display order; existing pack orders are preserved. Refresh lists after importing to obtain database IDs.

Missing accounts are searched and resolved through Mastodon by default. The configured Mastodon server must be running and `USER_ID` must be supplied for actual imports. Accounts are matched using actor URI, profile URL, or a qualified handle; JSON snapshot account IDs are not reused. Resolution happens before the pack transaction; if an account cannot be resolved, the import stops without changing packs. Remotely resolved accounts can persist even if a subsequent pack import fails. Use `RESOLVE_MISSING=false` only for an existing-accounts-only import that skips unmatched accounts. Dry runs never resolve remote accounts and roll back all pack writes, so their matched counts only include accounts already present locally.

Search tries the qualified handle, then the profile URL and actor URI when available. Strict failures identify the pack ID and creator/member position without printing profile data. To import available accounts despite deleted or unresolvable profiles, use `SKIP_UNRESOLVED=true`. Unresolved entries are reported and skipped; a pack with no resolved members is left unchanged rather than emptied. A previously assigned creator is retained if its snapshot cannot be resolved. Network or authentication errors still abort the import; they are not treated as deleted accounts.

## Cross-component behavior

The Dashboard owns the shared records. Newsmast Mastodon reads supported channel and community-admin data to expose custom feeds and channel-related automation. Dashboard services use the Mastodon REST API for operations such as account search, follows, hashtags, posting, and reblogging. A missing or incompatible gem leaves configuration data in place but does not provide gem-backed feed/automation behavior.

Relay support is an external-service integration and depends on valid Mastodon credentials plus the relay endpoint. It is not a replacement for the gem's own relay configuration.

## Related documentation

- [Content filters](content-filters.md)
- [Integrations](integrations.md)
- Newsmast Mastodon public [custom feeds guide](https://github.com/TheNewsmastFoundation/documentation/blob/main/newsmast-mastodon/features_custom_feeds.md)