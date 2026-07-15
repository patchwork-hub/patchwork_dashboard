# Integrations

> **Dependency:** External integrations are **Optional** unless the corresponding feature is enabled. Newsmast Mastodon is **Not required** for Dashboard-to-Mastodon REST operations, but is **Required** for gem-owned APIs and runtime extensions. Mechanisms: **Mastodon REST API**, **Patchwork Hub API**, **external service**, and **shared database**.

## Mastodon and Dashboard APIs

The Dashboard uses `MASTODON_INSTANCE_URL` and configured application credentials for outbound Mastodon REST calls. Its own `/api/v1` routes are authenticated by Dashboard API credentials by default, with documented bearer/client-credential exceptions. See [Dashboard API](../api/dashboard-api.md).

## Patchwork Hub

Patchwork Hub is optional. When configured, the Dashboard sends changed child server settings and obtains Hub-managed keyword-filter groups. Configure its URL and Dashboard API-key credentials. During Hub failures or unparseable Hub responses, keyword-filter refresh can treat the response as empty and remove existing non-custom groups for the affected setting; verify and restore expected groups after outages.

## Bluesky, Bridgy Fed, and DNS

The Dashboard contains Bluesky bridge services/jobs and can provision local-domain DNS records when `USE_LOCAL_DOMAIN=true`. This requires the selected DNS provider credentials and the external Bridgy Fed service. The supplied sample documents Route53; contribution guidance is in [CONTRIBUTING_DNS_PROVIDERS.md](../../CONTRIBUTING_DNS_PROVIDERS.md). DNS configuration is not required when using default Bridgy Fed handles.

## Relays and storage

Relay operations call an external relay/Mastodon endpoint using Mastodon credentials. In production, S3-compatible storage is configured through the S3 endpoint, bucket, region, and access credentials (it is not gated by `S3_ENABLED`). Test each provider in the target deployment.

## Explicit exclusions

Ghost, WordPress, Firebase, CiviCRM, drafts, reactions, automatic ALT text, and gem-specific content-webhook integrations are owned by Newsmast Mastodon or other host components, not by this Dashboard configuration surface. See the [Newsmast Mastodon documentation](https://github.com/TheNewsmastFoundation/documentation/tree/main/newsmast-mastodon).