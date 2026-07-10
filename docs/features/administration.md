# Administration

> **Dependency:** Newsmast Dashboard is **Required** for its browser administration workflows. Host Mastodon access is **Required** for account-facing operations. Mechanisms: **shared database**, **Mastodon REST API**, **Newsmast custom API**, and **OAuth/Doorkeeper**.

## Administrative capabilities

The Dashboard provides browser administration for accounts and follows, master administrators, roles, community administrators, wait lists, API keys, custom emoji, app versions, collections, and server settings. Account export is available through the account collection route. Community administrators can be associated with a channel, assigned an account status, and marked as boost bots.

Master-administrator management is restricted by the application authorization policy. Browser controllers use Devise authentication and Pundit authorization. Sidekiq Web at `/sidekiq` is accessible only to a master administrator or a user permitted to manage Sidekiq.

## API keys and API access

Dashboard API-key records are managed under the browser `api-key` resource. Most versioned API routes require `x-api-key` and `x-api-secret`; selected endpoints use bearer-token or client-credential logic. Review [Dashboard API](../api/dashboard-api.md) before exposing a client integration.

## Account and permission boundaries

The Dashboard can coordinate account, relationship, profile, status, and relay operations through the host Mastodon REST API and supported custom endpoints. It does not supersede Mastodon's own authorization model. Give the Mastodon application only the scopes it requires, and keep administrator credentials and API keys secret.

## Related documentation

- [Configuration](../configuration/environment-variables.md)
- [Troubleshooting](../troubleshooting/common-issues.md)
- Newsmast Mastodon public [accounts guide](../../../documentation/newsmast-mastodon/features_accounts.md)