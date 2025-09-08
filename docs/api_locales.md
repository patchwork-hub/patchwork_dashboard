# Locales API Documentation

This documentation covers the endpoints for managing application localization in the Patchwork Dashboard API.

## Base URL

```
https://api.patchwork.example/v1
```

## Authentication

Most endpoints require authentication with a bearer token in the Authorization header:

```
Authorization: Bearer YOUR_TOKEN_HERE
```

---

## Get Available Locales

Retrieves information about available locales and the current locale.

### URL

```
GET /api/v1/locale
```

### Authentication

API key required.

### Response

```json
{
  "current_locale": "en",
  "default_locale": "en",
  "available_locales": [
    {
      "code": "en",
      "name": "English",
      "native_name": "English",
      "is_default": true
    },
    {
      "code": "fr",
      "name": "French",
      "native_name": "Français",
      "is_default": false
    },
    // Additional locales
  ],
  "fallback_locales": {
    "fr": ["en"],
    // Additional fallback configurations
  }
}
```

---

## Get Specific Locale

Retrieves detailed information about a specific locale.

### URL

```
GET /api/v1/locale/:locale
```

### Authentication

API key required.

### Parameters

| Parameter | Type   | Description                           | Required |
|-----------|--------|---------------------------------------|----------|
| locale    | string | The locale code (e.g., 'en', 'fr')    | Yes      |

### Response

```json
{
  "locale": "fr",
  "name": "French",
  "native_name": "Français",
  "is_default": false,
  "fallback_locale": "en"
}
```

### Errors

- 404: If the requested locale is not found or not available.

---

## Set Session Locale

Sets the locale for the current session/request.

### URL

```
POST /api/v1/locale/set
```

### Authentication

API key required.

### Parameters

| Parameter | Type   | Description                           | Required |
|-----------|--------|---------------------------------------|----------|
| lang      | string | The locale code (e.g., 'en', 'fr')    | Yes      |

### Response

```json
{
  "locale": "fr",
  "message": "Success"
}
```

### Errors

- 400: If the requested locale is not available.

---

## Save User Locale Preference

Saves the user's locale preference to their profile in the database.

### URL

```
POST /api/v1/locale/save_preference
```

### Authentication

User authentication required (bearer token).

### Parameters

| Parameter | Type   | Description                           | Required |
|-----------|--------|---------------------------------------|----------|
| lang      | string | The locale code (e.g., 'en', 'fr')    | Yes      |

### Description

This endpoint allows authenticated users to save their locale preference to their user profile. The preference is stored in the database and will persist across sessions. The locale is also immediately set for the current session.

### Request Example

```http
POST /api/v1/locale/save_preference
Authorization: Bearer YOUR_TOKEN_HERE
Content-Type: application/json

{
  "lang": "fr"
}
```

### Response

```json
{
  "locale": "fr",
  "saved_to_profile": true,
  "message": "Updated successfully"
}
```

### Errors

- 400: If the requested locale is not available.
  ```json
  {
    "error": "Invalid request",
    "available_locales": ["en", "fr", "de", "it", "ja", "pt", "pt_BR", "ru", "cy"]
  }
  ```
- 401: If the user is not authenticated.
- 422: If the user's profile could not be updated (validation error).

---

## Get User Locale Preference

Retrieves the current user's saved locale preference.

### URL

```
GET /api/v1/locale/user_preference
```

### Authentication

User authentication required (bearer token).

### Response

```json
{
  "user_locale": "fr",
  "current_session_locale": "fr",
  "available_locales": [
    {
      "code": "en",
      "name": "English",
      "native_name": "English",
      "is_default": true
    },
    // Additional locales
  ]
}
```

### Errors

- 401: If the user is not authenticated.
- 404: If the user account is not found.

---

## Get Translations

Retrieves translations for a specific namespace.

### URL

```
GET /api/v1/locale/:locale/translations/:namespace
```

### Authentication

API key required.

### Parameters

| Parameter | Type   | Description                                   | Required |
|-----------|--------|-----------------------------------------------|----------|
| locale    | string | The locale code (e.g., 'en', 'fr')            | Yes      |
| namespace | string | The translation namespace (e.g., 'community') | No       |
| lang      | string | Alternative way to specify locale             | No       |

### Response

```json
{
  "locale": "fr",
  "namespace": "community",
  "translations": {
    "errors": {
      "not_found": "Communauté non trouvée",
      // Additional translations
    }
  }
}
```

### Errors

- 400: If the requested locale is not available.

---

## Implementation Notes

- The Locales API uses the I18n framework for internationalization.
- Translations are stored in YAML files in the `config/locales` directory.
- The API supports multiple languages including English, French, German, Italian, Japanese, Portuguese, Brazilian Portuguese, Russian, and Welsh.
- Locale settings are respected across the entire application, ensuring consistent localization.
- User locale preferences are stored in the user model's `locale` attribute.
