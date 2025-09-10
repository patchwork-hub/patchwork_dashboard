# App Versions API Documentation

This documentation covers the API endpoints for checking application version information and compatibility in the Patchwork Dashboard API.

## Base URL

```
https://api.patchwork.example/v1
```

## Authentication

The version check endpoint requires authentication via an Authorization header:

```
Authorization: Bearer YOUR_TOKEN_HERE
```

---

## Check Application Version

Checks if an application version is up to date and returns version history details.

### URL

```
GET /app_versions/check
```

### Method

```
GET
```

### URL Parameters

None

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| current_app_version | string | Yes | The current version of the application (format: major.minor.patch, e.g., "1.2.3") |
| app_name | string | No | The application name to check (default: "patchwork"). Options: "patchwork", "newsmast" |
| os_type | string | Yes | The operating system type (e.g., "ios", "android") |

### Success Response

**Code:** 200 OK

```json
{
  "message": "Operation completed successfully",
  "data": {
    "id": 5,
    "deprecated": false,
    "os_type": "ios",
    "created_at": "2025-07-15T10:22:35.000Z",
    "updated_at": "2025-07-15T10:22:35.000Z",
    "app_version_id": 12
  }
}
```

The response includes information about whether the current version is deprecated and other version history details.

### Error Responses

**Missing OS Type**

**Code:** 400 BAD REQUEST

```json
{
  "errors": "OS type is required"
}
```

**Version Not Found**

**Code:** 404 NOT FOUND

```json
{
  "errors": "Resource not found"
}
```

**Version History Not Found**

**Code:** 404 NOT FOUND

```json
{
  "errors": "Resource not found"
}
```

**Unauthorized**

**Code:** 401 UNAUTHORIZED

```json
{
  "errors": "You are not authorized to perform this action"
}
```

---

## API Responses in Different Languages

The API supports internationalization and will return messages in the language requested via the `Accept-Language` header.

### English Example (default)

```json
{
  "message": "Operation completed successfully",
  "data": { ... }
}
```

### Error Message Examples

For missing OS Type in various languages:

**English (default)**
```json
{
  "errors": "OS type is required"
}
```

**French**
```json
{
  "errors": "Le type de système d'exploitation est requis"
}
```

**German**
```json
{
  "errors": "Betriebssystemtyp ist erforderlich"
}
```

**Japanese**
```json
{
  "errors": "OSタイプは必須です"
}
```

To request a specific language, include the `Accept-Language` header in your request:

```
Accept-Language: fr
```

Supported languages: English (en), French (fr), German (de), Italian (it), Japanese (ja), Portuguese (pt), Brazilian Portuguese (pt-BR), Russian (ru), Welsh (cy).

---

## Data Model

### App Version

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique identifier for the version |
| app_name | integer | Application name (0: patchwork, 1: newsmast) |
| version_name | string | Version string in format "x.y.z" |
| created_at | datetime | When the version was created |
| updated_at | datetime | When the version was last updated |

### App Version History

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique identifier for the version history |
| app_version_id | integer | References the associated app version |
| deprecated | boolean | Whether this version is deprecated |
| os_type | string | Operating system type (e.g., "ios", "android") |
| created_at | datetime | When the history record was created |
| updated_at | datetime | When the history record was last updated |
