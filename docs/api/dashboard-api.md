# Dashboard API

This reference covers the versioned JSON routes defined in `config/routes/api_v1.rb`. Browser administration routes are intentionally excluded. Treat API keys and bearer tokens as secrets and use TLS.

## Authentication and errors

Most routes inherit `ApiController` and require both `x-api-key` and `x-api-secret` headers. Missing credentials return `401` with `{ "error": "API Key is missing" }`; invalid credentials return `401` with `{ "error": "API Key is invalid" }`. Some routes explicitly use `Authorization: Bearer <token>` or optional `client-id`/`client-secret`; see the route group below. Responses are JSON; pagination-capable endpoints include metadata where their controller provides it.

| Resource | Methods and paths | Auth | Purpose |
| --- | --- | --- | --- |
| Accounts | `GET/POST /api/v1/accounts`, `GET/PATCH/PUT/DELETE /api/v1/accounts/:id` | API key/secret | Account resource operations. |
| API key | `PATCH /api/v1/api_key/rotate` | API key/secret | Rotate a Dashboard API key. |
| Channels | `GET /api/v1/channels` collection routes for recommendation, search, detail, feeds, bridge information, and named channel sets; `PATCH /api/v1/channels/change_boost_bot_profile`; `GET /api/v1/channels/:id/starter_packs_detail` | API key/secret unless controller-specific | Channel discovery, detail, bridge, feed, and boost-bot operations. |
| Channel management | `GET/POST /api/v1/channels`; `GET/PATCH/PUT/DELETE /api/v1/channels/:id`; nested `community_filter_keywords`, `community_hashtags`, and `community_post_types` | API key/secret | Manage channel resources and related data. |
| Collections and content types | `GET /api/v1/collections`, `GET /api/v1/collections/{fetch_channels,newsmast_collections,channel_feed_collections}`, `GET/POST /api/v1/content_types` | API key/secret; content types use bearer auth | Read collections and manage content types. |
| Community administrators | `GET/PATCH /api/v1/community_admins/:id`, `GET /api/v1/community_admins`, `GET /api/v1/community_admins/boost_bot_accounts`, `POST /api/v1/community_admins/modify_account_status` | API key/secret; boost-bot endpoint uses static bearer token | Admin and boost-bot state. |
| Settings and server settings | `GET/DELETE /api/v1/settings`, `POST /api/v1/settings/upsert`, `GET /api/v1/server_settings`, `GET /api/v1/server_settings/menu_visibility` | Bearer/client credentials where controller specifies; otherwise API key/secret | User settings and server-setting visibility. |
| Users and locales | `GET/POST /api/v1/users/bluesky_bridge`, locale collection/member routes | Bearer token | Bluesky preference and localized settings. |
| Search and statuses | `POST /api/v1/search`, `POST /api/v1/statuses/boost_post` | API key/secret | Search and status boost actions. |
| Wait list | `POST /api/v1/wait_list`, `POST /api/v1/wait_list/request_invitation_code`, `GET /api/v1/wait_list/validate_code` | Controller-specific | Invitation and code validation. |
| Joined memberships | `GET/POST/DELETE /api/v1/joined_communities` and `/joined_working_groups`; `POST /api/v1/joined_communities/set_primary` and `/api/v1/joined_working_groups/set_primary` | API key/secret | Membership and primary-membership actions. |
| Supporting data | `GET /api/v1/domains/verify`, `/general_icons`, `/social_icons`, `GET /api/v1/app_versions/check_version`, `GET /api/v1/categories/bristol_latest_print` | API key/secret or client credentials for version check | Verification, display assets, compatibility, and category data. |

Route-specific parameters and response fields are controlled by their current controller/serializer. Consumers should use request tests or controller code for fields not represented by this public contract, rather than depending on browser-route payloads.