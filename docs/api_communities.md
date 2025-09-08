# Communities API Documentation

This documentation covers the endpoints for managing communities (channels) in the Patchwork Dashboard API.

## Base URL

```
https://api.patchwork.example/v1
```

## Authentication

All endpoints require authentication with a bearer token in the Authorization header:

```
Authorization: Bearer YOUR_TOKEN_HERE
```

---

## List Communities

Retrieves a paginated list of communities.

### URL

```
GET /communities
```

### Method

```
GET
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| page | integer | No | Page number (default: 1) |
| per_page | integer | No | Results per page (default: 5) |
| filter | string | No | Filter criteria for communities |

### Success Response

**Code:** 200 OK

```json
{
  "data": [
    {
      "id": "1",
      "type": "channel",
      "attributes": {
        "name": "Tech Community",
        "slug": "tech",
        "bio": "A community for technology discussions",
        "content_type": "custom_channel",
        "channel_type": "channel_feed",
        "visibility": "public_access",
        "is_recommended": true,
        "avatar_image_url": "https://example.com/avatar.jpg",
        "banner_image_url": "https://example.com/banner.jpg",
        "created_at": "2025-06-15T10:20:30.000Z"
      }
    }
  ]
}
```

### Error Response

Standard error responses apply.

---

## Create Community

Creates a new community.

### URL

```
POST /communities
```

### Method

```
POST
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| name | string | Yes | The name of the community |
| slug | string | Yes | The unique identifier for the community |
| bio | string | No | A short description of the community |
| collection_id | integer | No | The collection ID |
| banner_image | file | No | Banner image for the community |
| avatar_image | file | No | Avatar image for the community |
| community_type_id | integer | No | The community type ID |
| is_recommended | boolean | No | Whether the community should be recommended |
| is_custom_domain | boolean | No | Whether the community uses a custom domain |
| ip_address_id | integer | No | The IP address ID for the community |

### Success Response

**Code:** 201 CREATED

```json
{
  "message": "Community created successfully.",
  "data": {
    "community": {
      "id": 1,
      "name": "Tech Community",
      "slug": "tech",
      "bio": "A community for technology discussions",
      "created_at": "2025-08-28T12:34:56.789Z"
    }
  }
}
```

### Error Response

**Only One Channel Error**

**Code:** 403 FORBIDDEN

```json
{
  "error": "You can only create one channel."
}
```

**Validation Error**

**Code:** 422 UNPROCESSABLE ENTITY

```json
{
  "errors": "Validation failed!",
  "details": [
    "Name has already been taken",
    "Slug has already been taken"
  ]
}
```

---

## Show Community

Retrieves information about a specific community.

### URL

```
GET /communities/:id
```

### Method

```
GET
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | Yes | The ID of the community |

### Success Response

**Code:** 200 OK

```json
{
  "data": {
    "id": "1",
    "type": "channel",
    "attributes": {
      "name": "Tech Community",
      "slug": "tech",
      "bio": "A community for technology discussions",
      "content_type": "custom_channel",
      "channel_type": "channel_feed",
      "visibility": "public_access",
      "is_recommended": true,
      "avatar_image_url": "https://example.com/avatar.jpg",
      "banner_image_url": "https://example.com/banner.jpg",
      "created_at": "2025-06-15T10:20:30.000Z"
    },
    "relationships": {
      "patchwork_community_additional_informations": {
        "data": [
          {
            "id": "1",
            "type": "patchwork_community_additional_information"
          }
        ]
      },
      "patchwork_community_links": {
        "data": [
          {
            "id": "1",
            "type": "patchwork_community_link"
          }
        ]
      },
      "patchwork_community_rules": {
        "data": [
          {
            "id": "1",
            "type": "patchwork_community_rule"
          }
        ]
      }
    }
  }
}
```

### Error Response

**Not Found Error**

**Code:** 404 NOT FOUND

```json
{
  "error": "Resource not found."
}
```

**Access Denied Error**

**Code:** 403 FORBIDDEN

```json
{
  "error": "Access denied!"
}
```

---

## Update Community

Updates an existing community.

### URL

```
PUT /communities/:id
```

### Method

```
PUT
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | Yes | The ID of the community |

### Request Parameters

Same as the Create Community endpoint.

### Success Response

**Code:** 200 OK

```json
{
  "message": "Community updated successfully.",
  "data": {
    "community": {
      "id": 1,
      "name": "Updated Tech Community",
      "slug": "tech",
      "bio": "An updated description",
      "updated_at": "2025-08-28T14:45:30.789Z"
    }
  }
}
```

### Error Response

Same as Create Community endpoint.

---

## Get Community Types

Retrieves a list of available community types.

### URL

```
GET /communities/community_types
```

### Method

```
GET
```

### Success Response

**Code:** 200 OK

```json
{
  "data": [
    { "id": 1, "name": "Technology" },
    { "id": 2, "name": "Arts" },
    { "id": 3, "name": "Science" }
  ]
}
```

---

## Get Collections

Retrieves a list of available collections.

### URL

```
GET /communities/collections
```

### Method

```
GET
```

### Success Response

**Code:** 200 OK

```json
{
  "data": [
    { "id": 1, "name": "Featured" },
    { "id": 2, "name": "Popular" },
    { "id": 3, "name": "New" }
  ]
}
```

---

## Search Contributors

Searches for contributors (accounts) based on a query.

### URL

```
GET /communities/search_contributor
```

### Method

```
GET
```

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| query | string | Yes | The search query for contributors |
| instance_domain | string | No | Optional domain to limit search to a specific instance |

### Success Response

**Code:** 200 OK

```json
{
  "accounts": [
    {
      "id": "1",
      "username": "user1",
      "display_name": "User One",
      "avatar": "https://example.com/avatar1.jpg",
      "url": "https://example.com/@user1"
    },
    {
      "id": "2",
      "username": "user2",
      "display_name": "User Two",
      "avatar": "https://example.com/avatar2.jpg",
      "url": "https://example.com/@user2"
    }
  ]
}
```

### Error Response

**Missing Parameters Error**

**Code:** 400 BAD REQUEST

```json
{
  "error": "Query, URL, and token parameters are required."
}
```

---

## List Community Contributors

Retrieves a list of contributors for a specific community.

### URL

```
GET /communities/:patchwork_community_id/contributor_list
```

### Method

```
GET
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| patchwork_community_id | string/integer | Yes | The ID or slug of the community |

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| page | integer | No | Page number (default: 1) |
| per_page | integer | No | Results per page (default: 5) |
| instance_domain | string | No | Optional domain to limit results to a specific instance |

### Success Response

**Code:** 200 OK

```json
{
  "contributors": [
    {
      "id": "1",
      "type": "contributor",
      "attributes": {
        "username": "user1",
        "display_name": "User One",
        "avatar_url": "https://example.com/avatar1.jpg",
        "following": true,
        "followed_by": false
      }
    }
  ],
  "meta": {
    "current_page": 1,
    "next_page": 2,
    "prev_page": null,
    "total_pages": 5,
    "total_count": 23
  }
}
```

### Error Response

**Invalid Request Error**

**Code:** 400 BAD REQUEST

```json
{
  "error": "Invalid request!"
}
```

**Community Not Found Error**

**Code:** 404 NOT FOUND

```json
{
  "error": "Resource not found."
}
```

---

## List Community Hashtags

Retrieves a list of hashtags for a specific community.

### URL

```
GET /communities/:patchwork_community_id/hashtag_list
```

### Method

```
GET
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| patchwork_community_id | string/integer | Yes | The ID or slug of the community |

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| page | integer | No | Page number (default: 1) |
| per_page | integer | No | Results per page (default: 5) |

### Success Response

**Code:** 200 OK

```json
{
  "data": [
    {
      "id": 1,
      "hashtag": "technology",
      "name": "technology",
      "patchwork_community_id": 5,
      "created_at": "2025-06-10T14:30:00.000Z",
      "updated_at": "2025-06-10T14:30:00.000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "total_count": 1
  }
}
```

### Error Response

Similar to the contributor_list endpoint.

---

## List Muted Contributors

Retrieves a list of muted contributors for a specific community.

### URL

```
GET /communities/:patchwork_community_id/mute_contributor_list
```

### Method

```
GET
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| patchwork_community_id | string/integer | Yes | The ID or slug of the community |

### Query Parameters

Same as contributor_list endpoint.

### Success Response

**Code:** 200 OK

Structure similar to the contributor_list endpoint.

### Error Response

Similar to the contributor_list endpoint.

---

## Set Community Visibility

Sets the visibility of a community.

### URL

```
PUT /communities/:id/set_visibility
```

### Method

```
PUT
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | Yes | The ID of the community |

### Success Response

**Created (First Time)**

**Code:** 201 CREATED

```json
{
  "message": "Resource created successfully"
}
```

**Updated (Subsequent Times)**

**Code:** 200 OK

```json
{
  "message": "Resource updated successfully"
}
```

### Error Response

**Unauthorized Error**

**Code:** 403 FORBIDDEN

```json
{
  "error": "Access denied!"
}
```

---

## Manage Additional Information

Updates additional information for a community.

### URL

```
PUT /communities/:id/manage_additional_information
```

### Method

```
PUT
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | Yes | The ID of the community |

### Request Body

```json
{
  "community": {
    "patchwork_community_additional_informations_attributes": [
      { "id": 1, "heading": "About", "text": "Community information", "_destroy": false }
    ],
    "social_links_attributes": [
      { "id": 1, "icon": "twitter", "name": "Twitter", "url": "https://twitter.com/example", "_destroy": false }
    ],
    "general_links_attributes": [
      { "id": 1, "icon": "link", "name": "Website", "url": "https://example.com", "_destroy": false }
    ],
    "patchwork_community_rules_attributes": [
      { "id": 1, "rule": "Be respectful", "_destroy": false }
    ],
    "registration_mode": ["open"]
  }
}
```

### Success Response

**Code:** 200 OK

Returns the community with included relationships (same format as the show endpoint).

### Error Response

**Missing Information Error**

**Code:** 422 UNPROCESSABLE ENTITY

```json
{
  "errors": "Missing additional information."
}
```

**Invalid Request Error**

**Code:** 400 BAD REQUEST

```json
{
  "error": "Invalid request!"
}
```

**Duplicate Link URL Error**

**Code:** 422 UNPROCESSABLE ENTITY

```json
{
  "errors": "Duplicate link URL for this community is not allowed."
}
```

---

## Fetch IP Address

Retrieves the IP address associated with a community.

### URL

```
GET /communities/:id/fetch_ip_address
```

### Method

```
GET
```

### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | Yes | The ID of the community |

### Success Response

**Code:** 200 OK

```json
{
  "ip_address": "192.0.2.1",
  "id": 1
}
```

### Error Response

**Not Found Error**

**Code:** 404 NOT FOUND

```json
{
  "error": "No valid IP available"
}
```

---

## API Responses in Different Languages

The API supports internationalization and will return messages in the language requested via the `Accept-Language` header.

### English Example (default)

```json
{
  "message": "Community created successfully.",
  "data": { /* ... */ }
}
```

### French Example

```json
{
  "message": "Communauté créée avec succès.",
  "data": { /* ... */ }
}
```

To request a specific language, include the `Accept-Language` header in your request:

```
Accept-Language: fr
```

Supported languages: English (en), French (fr), German (de), Italian (it), Japanese (ja), Portuguese (pt), Brazilian Portuguese (pt-BR), Russian (ru), Welsh (cy).
