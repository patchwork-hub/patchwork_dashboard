# Community Hashtags API Documentation

This documentation covers the endpoints available for managing hashtags within a community in the Patchwork Dashboard API.

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

## List Community Hashtags

Retrieves a paginated list of hashtags associated with a specific community.

### URL

```
GET /communities/:community_id/hashtags
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| community_id | string | Yes | The community ID or slug |
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
      "patchwork_community_id": 42,
      "created_at": "2025-07-10T14:22:45.000Z",
      "updated_at": "2025-07-10T14:22:45.000Z"
    },
    {
      "id": 2,
      "hashtag": "programming",
      "name": "programming",
      "patchwork_community_id": 42,
      "created_at": "2025-07-09T10:15:30.000Z",
      "updated_at": "2025-07-09T10:15:30.000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 3,
    "per_page": 5,
    "total_count": 12
  }
}
```

### Error Response

**Code:** 400 BAD REQUEST

```json
{
  "error": "Patchwork community ID is required"
}
```

**Code:** 404 NOT FOUND

```json
{
  "error": "Patchwork community not found"
}
```

**Code:** 403 FORBIDDEN

```json
{
  "error": "You are not authorized to perform this action"
}
```

---

## Create Community Hashtag

Add a new hashtag to a community.

### URL

```
POST /communities/:community_id/hashtags
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| community_id | string | Yes | The community ID or slug |

### Request Body

```json
{
  "community_hashtag": {
    "hashtag": "technology"
  }
}
```

### Success Response

**Code:** 201 CREATED

```json
{
  "message": "Hashtag saved successfully!",
  "data": {}
}
```

### Error Response

**Code:** 400 BAD REQUEST

```json
{
  "error": "Required parameter is missing"
}
```

**Code:** 409 CONFLICT

```json
{
  "error": "Duplicate entry: Hashtag already exists"
}
```

**Code:** 422 UNPROCESSABLE ENTITY

```json
{
  "error": "Invalid hashtag format"
}
```

---

## Update Community Hashtag

Update an existing hashtag in a community.

### URL

```
PUT /communities/:community_id/hashtags/:id
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| community_id | string | Yes | The community ID or slug |
| id | integer | Yes | The hashtag ID |

### Request Body

```json
{
  "community_hashtag": {
    "hashtag": "new_technology_tag"
  }
}
```

### Success Response

**Code:** 200 OK

```json
{
  "message": "Hashtag updated successfully!",
  "data": {}
}
```

### Error Response

**Code:** 400 BAD REQUEST

```json
{
  "error": "Required parameter is missing"
}
```

**Code:** 409 CONFLICT

```json
{
  "error": "Duplicate entry: Hashtag already exists"
}
```

**Code:** 422 UNPROCESSABLE ENTITY

```json
{
  "error": "Invalid hashtag format"
}
```

OR

```json
{
  "error": "Hashtag cannot contain spaces"
}
```

**Code:** 404 NOT FOUND

```json
{
  "error": "Resource not found"
}
```

---

## Delete Community Hashtag

Remove a hashtag from a community.

### URL

```
DELETE /communities/:community_id/hashtags/:id
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| community_id | string | Yes | The community ID or slug |
| id | integer | Yes | The hashtag ID |

### Success Response

**Code:** 200 OK

```json
{
  "message": "Hashtag removed successfully!"
}
```

### Error Response

**Code:** 404 NOT FOUND

```json
{
  "error": "Resource not found"
}
```

**Code:** 500 INTERNAL SERVER ERROR

```json
{
  "error": "An internal server error occurred"
}
```

---

## API Responses in Different Languages

The API supports internationalization and will return messages in the language requested via the `Accept-Language` header. For example:

### English Example (default)

```json
{
  "message": "Hashtag saved successfully!",
  "data": {}
}
```

### French Example

```json
{
  "message": "Hashtag enregistré avec succès !",
  "data": {}
}
```

### German Example

```json
{
  "message": "Hashtag erfolgreich gespeichert!",
  "data": {}
}
```

### Japanese Example

```json
{
  "message": "ハッシュタグが正常に保存されました！",
  "data": {}
}
```

To request a specific language, include the `Accept-Language` header in your request:

```
Accept-Language: fr
```

Supported languages: English (en), French (fr), German (de), Italian (it), Japanese (ja), Portuguese (pt), Brazilian Portuguese (pt-BR), Russian (ru), Welsh (cy).
