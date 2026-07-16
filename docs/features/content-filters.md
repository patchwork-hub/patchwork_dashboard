# Content filters

> **Dependency:** Newsmast Dashboard is **Required** to manage Dashboard filter groups and community filter keywords. Newsmast Mastodon is **Required** to enforce its supported filtering and feed behavior. Mechanisms: **shared database**, **Patchwork Hub API**, and **Redis/Sidekiq**.

## Capabilities

Operators manage global keyword-filter groups and individual keywords through the Dashboard. Groups can be associated with the server-level `spam_filters` or `content_filters` setting and can be active/inactive. Community filter keywords support channel-specific filter-in and filter-out data. CSV download is available from the global filter-group interface.

## Refresh and synchronization behavior

Changing the boolean value of `content_filters` or `spam_filters` calls `KeywordFiltersJob` immediately. When enabled, the job requests non-custom filter groups from Patchwork Hub using the configured Hub URL and stored Dashboard API credentials. When disabled, it deletes non-custom groups for that server setting when such groups exist. Scheduled `FetchContentKeywordScheduler` and `FetchSpamKeywordScheduler` invoke the same job for their respective settings.

This is configuration synchronization, not a claim that the Dashboard itself filters Mastodon timelines. Newsmast Mastodon owns its extended filter enforcement, cache use, and feed behavior. Verify both systems and Redis when a filter appears not to take effect.

## Configuration and failure behavior

Configure `PATCHWORK_HUB_URL`, Redis, and a Dashboard API key/secret before expecting Hub-managed groups to refresh. The filter job returns without action when the referenced `ServerSetting` does not exist. Failed Hub requests are logged by the service/job path; inspect application and Sidekiq logs without exposing credentials. If Hub requests fail or return unparseable data, the current implementation can treat that as an empty Hub result and remove existing non-custom groups for the affected setting; verify group state after incidents.

## Related documentation

- [Server settings](server-settings.md)
- [Troubleshooting filters](../troubleshooting/common-issues.md)
- Newsmast Mastodon public [content-filters guide](https://github.com/TheNewsmastFoundation/documentation/blob/main/newsmast-mastodon/features_content_filters.md)