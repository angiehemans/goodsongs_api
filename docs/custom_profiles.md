# PRD: Profile Customization — Backend (Rails API)

## Implementation Status

**Status:** ✅ Implemented (March 2026)

### Files Created
- `db/migrate/20260302000001_create_profile_themes.rb`
- `db/migrate/20260302000002_create_profile_assets.rb`
- `db/migrate/20260302000003_add_profile_customization_abilities.rb`
- `app/models/profile_theme.rb`
- `app/models/profile_asset.rb`
- `app/services/profile_theme_validator.rb`
- `app/controllers/api/v1/profile_themes_controller.rb`
- `app/controllers/api/v1/profile_assets_controller.rb`
- `app/controllers/api/v1/profiles_controller.rb`
- `app/serializers/profile_theme_serializer.rb`
- `app/serializers/profile_asset_serializer.rb`

### Files Modified
- `app/models/user.rb` - Added `has_one :profile_theme`, `has_many :profile_assets`
- `config/routes.rb` - Added profile customization routes

### Implementation Notes
- Uses `user_id` instead of `account_id` (codebase convention)
- Profile assets use Active Storage instead of direct CDN URLs
- Section `order` field is explicit (not inferred from array index) for clearer client handling
- Abilities created: `can_customize_profile`, `profile_mailing_list_section`, `profile_merch_section`

---

## Overview

Paid band and blogger accounts on GoodSongs need the ability to customize their public profiles with configurable sections, theming, and layout ordering. This document covers the data model, API endpoints, validation, and asset handling required to support the profile site builder.

## Goals

- Store per-account theme configurations (colors, fonts, section order, section-level overrides) in a flexible, extensible schema
- Provide CRUD API endpoints for theme management with draft/publish workflow
- Serve optimized theme + content payloads for public profile rendering
- Enforce access control so only paid band and blogger accounts can customize profiles
- Support background image uploads with CDN-ready asset management

## Eligibility

Profile customization is available to all paid accounts:

- **Band Starter** ($15/mo)
- **Band Pro** ($40/mo)
- **Blogger** ($9/mo)
- **Blogger Pro** ($18/mo)

Free fan accounts see a default, non-customizable profile.

All paid plans get the full customization toolkit: global theming, section-level overrides, background images, custom text sections, and drag-and-drop reordering. The only plan-level difference is **which section types are available** (see Section Availability by Plan below). This keeps the builder experience simple — no locked controls or blurred-out settings within the tool itself.

---

## Data Model

### `profile_themes` table

| Column             | Type      | Constraints            | Notes                                        |
| ------------------ | --------- | ---------------------- | -------------------------------------------- |
| `id`               | bigint    | PK                     |                                              |
| `account_id`       | bigint    | FK → accounts, unique  | One theme per account                        |
| `background_color` | string(7) | default `"#ffffff"`    | Hex color, global default                    |
| `brand_color`      | string(7) | default `"#000000"`    | Accent/CTA color                             |
| `font_color`       | string(7) | default `"#1a1a1a"`    | Global text color                            |
| `header_font`      | string    | default `"Inter"`      | From approved font list                      |
| `body_font`        | string    | default `"Inter"`      | From approved font list                      |
| `sections`         | jsonb     | not null, default `[]` | Published section config                     |
| `draft_sections`   | jsonb     | default `null`         | Unpublished draft, null = no pending changes |
| `published_at`     | datetime  | nullable               | Last publish timestamp                       |
| `created_at`       | datetime  |                        |                                              |
| `updated_at`       | datetime  |                        |                                              |

**Indexes:**

- Unique index on `account_id`
- Index on `published_at` (for cache invalidation queries)

**Note on global theme fields:** `background_color`, `brand_color`, `font_color`, `header_font`, and `body_font` are stored as top-level columns rather than inside JSON. This makes validation simpler, avoids JSON parsing for common queries, and keeps the most-accessed fields indexable. These fields are always "live" — there is no draft state for global settings, only for sections. If draft/publish is later needed for global settings, these can be moved into a `draft_globals` JSON column.

### Section JSON Schema

The `sections` and `draft_sections` columns store an ordered JSON array. Position is determined by array index — no explicit `position` field is needed.

```json
[
  {
    "type": "hero",
    "visible": true,
    "settings": {
      "background_color": null,
      "background_image_url": null,
      "font_color": null,
      "headline": "We are The Midnight Pines",
      "subtitle": "Portland, OR",
      "cta_text": "Listen Now",
      "cta_url": "https://..."
    }
  },
  {
    "type": "music",
    "visible": true,
    "settings": {
      "background_color": "#222222",
      "background_image_url": null,
      "font_color": null,
      "display_limit": 6,
      "layout": "grid"
    }
  }
]
```

### Section Types and Their Settings

Every section supports these shared override fields:

- `background_color` (string|null) — hex, overrides global
- `background_image_url` (string|null) — URL to uploaded asset, Pro plans only
- `font_color` (string|null) — hex, overrides global

Section-specific settings by type:

**`hero`**

- `headline` (string, max 120 chars)
- `subtitle` (string, max 200 chars)
- `cta_text` (string|null, max 40 chars)
- `cta_url` (string|null, valid URL)

**`music`**

- `display_limit` (integer, 3–24, default 6)
- `layout` (enum: `"grid"` | `"list"`, default `"grid"`)

**`events`**

- `display_limit` (integer, 3–12, default 6)
- `show_past_events` (boolean, default false)

**`posts`**

- `display_limit` (integer, 3–12, default 6)

**`about`**

- `body` (text, max 5000 chars, supports basic markdown: bold, italic, links)

**`recommendations`**

- `display_limit` (integer, 3–24, default 12)
- `layout` (enum: `"grid"` | `"list"`, default `"grid"`)

**`mailing_list`**

- `heading` (string, max 120 chars, default "Stay in the loop")
- `description` (string, max 500 chars)
- `provider` (enum: `"native"` | `"mailchimp"` | `"convertkit"`)
- `external_form_url` (string|null, required if provider is not `"native"`)

**`merch`**

- `heading` (string, max 120 chars, default "Merch")
- `provider` (enum: `"bandcamp"` | `"bigcartel"` | `"custom_link"`)
- `external_url` (string, required, valid URL)
- `display_limit` (integer, 3–12, default 6)

**`custom_text`** (can appear multiple times)

- `heading` (string, max 120 chars)
- `body` (text, max 10000 chars, supports basic markdown)

### Validation Rules

**Section array rules:**

- Maximum 12 sections total
- Predefined types (`hero`, `music`, `events`, `posts`, `about`, `recommendations`, `mailing_list`, `merch`) can each appear at most once
- `custom_text` can appear up to 3 times
- At least one section must be visible

**Type-specific validation:**

- All `*_color` fields must match `/^#[0-9a-fA-F]{6}$/`
- All `*_url` fields must be valid HTTPS URLs
- `background_image_url` must reference an asset owned by the account (see Profile Assets below)
- `font` fields must be from the approved font list (see Appendix)
- Enum fields must match their allowed values
- String lengths enforced per the limits above

**Plan-gated validation:**

- Section types are gated by plan (see Section Availability by Plan below). If a section type is not available on the account's current plan, it must not appear in the sections array.
- If an account downgrades and loses access to a section type, those sections are preserved in the database but excluded from the public profile response. If they upgrade again, the sections reappear.

Validation should be implemented as a service object (`ProfileThemeValidator`) that runs on both `sections` and `draft_sections` before persistence.

### `profile_assets` table

| Column       | Type     | Constraints            | Notes                     |
| ------------ | -------- | ---------------------- | ------------------------- |
| `id`         | bigint   | PK                     |                           |
| `account_id` | bigint   | FK → accounts          |                           |
| `file_url`   | string   | not null               | CDN URL after upload      |
| `file_type`  | string   | not null               | MIME type                 |
| `file_size`  | integer  | not null               | Bytes                     |
| `purpose`    | string   | default `"background"` | For future categorization |
| `created_at` | datetime |                        |                           |

**Constraints:**

- Maximum 20 assets per account
- Maximum file size: 5MB
- Allowed types: `image/jpeg`, `image/png`, `image/webp`
- Images should be processed on upload: strip EXIF, resize to max 2400px wide, generate a 400px thumbnail for the builder preview

---

## API Endpoints

All endpoints require authentication. Account must have an eligible paid plan unless noted.

### `GET /api/v1/profile_theme`

Returns the current account's theme configuration.

**Response (200):**

```json
{
  "profile_theme": {
    "background_color": "#1a1a1a",
    "brand_color": "#ff6b35",
    "font_color": "#f0f0f0",
    "header_font": "Space Grotesk",
    "body_font": "Inter",
    "sections": [ ... ],
    "draft_sections": [ ... ] | null,
    "has_unpublished_changes": true,
    "published_at": "2026-02-28T15:30:00Z"
  }
}
```

If no theme exists yet, return a default theme object with standard sections in the default order and all settings null/default.

### `PUT /api/v1/profile_theme`

Updates the theme. Saves section changes to `draft_sections` and global settings immediately.

**Request body:**

```json
{
  "profile_theme": {
    "background_color": "#1a1a1a",
    "brand_color": "#ff6b35",
    "font_color": "#f0f0f0",
    "header_font": "Space Grotesk",
    "body_font": "Inter",
    "draft_sections": [ ... ]
  }
}
```

**Response (200):** Updated theme object.
**Response (422):** Validation errors with field-level detail.

### `POST /api/v1/profile_theme/publish`

Copies `draft_sections` to `sections`, sets `published_at`, clears `draft_sections`.

**Response (200):** Updated theme object with `has_unpublished_changes: false`.
**Response (422):** If `draft_sections` is null (nothing to publish).

### `POST /api/v1/profile_theme/discard_draft`

Sets `draft_sections` to null, discarding unpublished changes.

**Response (200):** Updated theme object.

### `POST /api/v1/profile_theme/reset`

Resets the theme to defaults. Sets `sections` to the default array, clears `draft_sections`, resets all global fields to defaults.

**Response (200):** Default theme object.

### `POST /api/v1/profile_assets`

Uploads a background image. Accepts multipart form data. Available to all paid accounts.

**Request:** `file` (multipart), `purpose` (string, optional)
**Response (201):**

```json
{
  "asset": {
    "id": 42,
    "file_url": "https://cdn.goodsongs.app/profiles/abc123/bg-hero.jpg",
    "thumbnail_url": "https://cdn.goodsongs.app/profiles/abc123/bg-hero-thumb.jpg",
    "file_type": "image/jpeg",
    "file_size": 245000
  }
}
```

**Response (422):** File too large, wrong type, or asset limit reached.

### `DELETE /api/v1/profile_assets/:id`

Deletes an uploaded asset. If the asset is referenced in any section's `background_image_url`, that field is set to null.

**Response (200):** Success.
**Response (404):** Asset not found or not owned by account.

### `GET /api/v1/profiles/:username` (public, no auth required)

Returns the published profile for public rendering. This is the endpoint the frontend hits when any visitor loads a profile.

**Response (200):**

```json
{
  "profile": {
    "account": {
      "username": "midnightpines",
      "display_name": "The Midnight Pines",
      "avatar_url": "https://...",
      "account_type": "band"
    },
    "theme": {
      "background_color": "#1a1a1a",
      "brand_color": "#ff6b35",
      "font_color": "#f0f0f0",
      "header_font": "Space Grotesk",
      "body_font": "Inter"
    },
    "sections": [
      {
        "type": "hero",
        "settings": { ... }
      },
      {
        "type": "music",
        "settings": { "display_limit": 6, "layout": "grid" },
        "data": {
          "releases": [ ... ]
        }
      },
      {
        "type": "events",
        "settings": { "display_limit": 6, "show_past_events": false },
        "data": {
          "events": [ ... ]
        }
      }
    ]
  }
}
```

**Key detail:** Only visible sections are included. Each section that renders live data includes a `data` key with the relevant records, pre-queried according to the section's settings (e.g., respecting `display_limit`, filtering past events). The client should not need to make additional API calls to render the profile.

**Caching:** This endpoint should be cached aggressively. Recommended approach: HTTP cache headers with `ETag` based on a hash of `profile_theme.updated_at` + latest content timestamps. Cache should be invalidated when the theme is published or when the account's content changes (new release, new event, etc.).

---

## Default Section Configuration

When an account first accesses profile customization, a `profile_theme` record is created with this default `sections` array:

```json
[
  { "type": "hero", "visible": true, "settings": {} },
  { "type": "music", "visible": true, "settings": {} },
  { "type": "events", "visible": true, "settings": {} },
  { "type": "posts", "visible": true, "settings": {} },
  { "type": "about", "visible": true, "settings": {} },
  { "type": "recommendations", "visible": true, "settings": {} },
  { "type": "mailing_list", "visible": false, "settings": {} },
  { "type": "merch", "visible": false, "settings": {} }
]
```

Mailing list and merch default to hidden since they require external configuration before they're useful.

---

## Abilities Integration

Profile customization access should be gated through the existing roles/plans/abilities system:

| Ability                 | Plans                                        |
| ----------------------- | -------------------------------------------- |
| `can_customize_profile` | Band Starter, Band Pro, Blogger, Blogger Pro |

All customization capabilities (theming, section overrides, background images, reordering) are included with this single ability. No need for tiered customization abilities.

### Section Availability by Plan

The plan-level distinction controls which section types an account can add to their profile:

| Section Type      | Band Starter | Band Pro | Blogger | Blogger Pro |
| ----------------- | ------------ | -------- | ------- | ----------- |
| `hero`            | ✓            | ✓        | ✓       | ✓           |
| `music`           | ✓            | ✓        | ✓       | ✓           |
| `events`          | ✓            | ✓        | ✓       | ✓           |
| `posts`           | ✓            | ✓        | ✓       | ✓           |
| `about`           | ✓            | ✓        | ✓       | ✓           |
| `recommendations` | ✓            | ✓        | ✓       | ✓           |
| `custom_text`     | ✓            | ✓        | ✓       | ✓           |
| `mailing_list`    | —            | ✓        | —       | ✓           |
| `merch`           | —            | ✓        | —       | —           |

This mapping should be stored as a config constant referenced by the validator and serialized to the frontend so the builder UI can show/hide section types accordingly. The mapping is intentionally a simple lookup — no complex permission inheritance needed.

**Note:** This table will evolve as new section types and plans are added. The architecture supports this by treating section availability as configuration, not code.

---

## Migration Plan

1. Create `profile_themes` table and model
2. Create `profile_assets` table and model
3. Implement `ProfileThemeValidator` service
4. Build authenticated CRUD endpoints
5. Build public profile endpoint with data hydration
6. Add abilities to plans
7. Add cache layer to public endpoint

---

## Appendix: Approved Font List

These fonts are available via Google Fonts and selected for quality pairing and readability:

Inter, Space Grotesk, DM Sans, Plus Jakarta Sans, Outfit, Sora, Manrope, Rubik, Work Sans, Nunito Sans, Lora, Merriweather, Playfair Display, Source Serif 4, Libre Baskerville, IBM Plex Mono, JetBrains Mono

This list can be extended without a migration — the validator references a config constant.

---

## Implemented API Reference

### Authentication

All endpoints except `GET /api/v1/profiles/:username` require authentication via Bearer token. Profile customization endpoints also require the `can_customize_profile` ability.

### Endpoints

#### `GET /api/v1/profile_theme`

Returns the authenticated user's theme configuration including draft.

**Response (200):**
```json
{
  "data": {
    "id": 1,
    "user_id": 42,
    "background_color": "#121212",
    "brand_color": "#6366f1",
    "font_color": "#f5f5f5",
    "header_font": "Inter",
    "body_font": "Inter",
    "sections": [...],
    "draft_sections": [...] | null,
    "has_draft": true,
    "published_at": "2026-03-02T10:30:00Z",
    "created_at": "2026-03-01T09:00:00Z",
    "updated_at": "2026-03-02T10:30:00Z",
    "config": {
      "approved_fonts": ["Inter", "Space Grotesk", ...],
      "section_types": ["hero", "music", "events", ...],
      "max_sections": 12,
      "max_custom_text": 3
    }
  }
}
```

#### `PUT /api/v1/profile_theme`

Updates theme settings. Section changes go to `draft_sections`.

**Request:**
```json
{
  "background_color": "#1a1a1a",
  "brand_color": "#ff6b35",
  "header_font": "Space Grotesk",
  "sections": [
    { "type": "hero", "visible": true, "order": 0 },
    { "type": "music", "visible": true, "order": 1 }
  ]
}
```

**Response (200):** Updated theme object
**Response (403):** `{ "error": "upgrade_required", ... }` if missing ability
**Response (422):** `{ "error": "validation_error", "details": [...] }`

#### `POST /api/v1/profile_theme/publish`

Publishes draft sections.

**Response (200):** `{ "data": {...}, "message": "Theme published successfully" }`
**Response (422):** `{ "error": "no_draft", "message": "No draft to publish" }`

#### `POST /api/v1/profile_theme/discard_draft`

Discards unpublished draft sections.

**Response (200):** `{ "data": {...}, "message": "Draft discarded" }`

#### `POST /api/v1/profile_theme/reset`

Resets theme to role-based defaults.

**Response (200):** `{ "data": {...}, "message": "Theme reset to defaults" }`

#### `GET /api/v1/profile_assets`

Lists authenticated user's uploaded assets.

**Response (200):**
```json
{
  "data": [
    {
      "id": 1,
      "purpose": "background",
      "url": "https://...",
      "thumbnail_url": "https://...",
      "file_type": "image/jpeg",
      "file_size": 245000,
      "created_at": "2026-03-01T09:00:00Z"
    }
  ],
  "meta": {
    "total": 1,
    "limit": 20
  }
}
```

#### `POST /api/v1/profile_assets`

Uploads a new asset (multipart form).

**Request:** `image` (file), `purpose` (string: "background" | "header" | "custom")
**Response (201):** Asset object
**Response (422):** Validation errors (file too large, wrong type, limit reached)

#### `DELETE /api/v1/profile_assets/:id`

Deletes an asset.

**Response (200):** `{ "message": "Asset deleted successfully" }`
**Response (404):** `{ "error": "not_found" }`

#### `GET /api/v1/profiles/:username` (Public)

Returns public profile with hydrated section data. No authentication required.

**Response (200):**
```json
{
  "data": {
    "user": {
      "id": 42,
      "username": "midnightpines",
      "display_name": "The Midnight Pines",
      "profile_image_url": "https://...",
      "role": "band",
      ...
    },
    "theme": {
      "background_color": "#121212",
      "brand_color": "#6366f1",
      "font_color": "#f5f5f5",
      "header_font": "Inter",
      "body_font": "Inter"
    },
    "sections": [
      {
        "type": "hero",
        "order": 0,
        "content": {},
        "data": {
          "display_name": "The Midnight Pines",
          "profile_image_url": "https://...",
          "location": "Portland, OR",
          "band": {...}
        }
      },
      {
        "type": "music",
        "order": 1,
        "content": {},
        "data": {
          "band": {...},
          "tracks": [...],
          "bandcamp_embed": "..."
        }
      },
      {
        "type": "events",
        "order": 2,
        "content": {},
        "data": {
          "events": [...]
        }
      }
    ]
  }
}
```

**Response (404):** `{ "error": "not_found", "message": "User not found" }`
