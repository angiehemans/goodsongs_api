# GoodSongs API Documentation

Base URL: `https://api.goodsongs.app` (production) or `http://localhost:3000` (development)

## Authentication

All authenticated endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

---

## Auth Endpoints

### POST /signup

Create a new user account.

**Authentication:** None

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "password123",
  "password_confirmation": "password123"
}
```

**Response (201 Created):**

```json
{
  "message": "Account created successfully",
  "auth_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

---

### POST /login

Authenticate and receive a JWT token.

**Authentication:** None

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**

```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

---

### POST /password/forgot

Request a password reset email. Always returns success to prevent email enumeration.

**Authentication:** None

**Request Body:**

```json
{
  "email": "user@example.com"
}
```

**Response (200 OK):**

```json
{
  "message": "If an account exists with this email, a password reset link has been sent"
}
```

**Notes:**

- Rate limited to prevent abuse
- Disabled accounts will not receive reset emails
- Token expires after 2 hours

---

### GET /password/validate-token

Check if a password reset token is valid. Useful for frontend to show appropriate UI before user enters new password.

**Authentication:** None

**Query Parameters:**

- `token` (required): The password reset token from the email link

**Response (200 OK) - Valid Token:**

```json
{
  "valid": true
}
```

**Response (200 OK) - Invalid/Expired Token:**

```json
{
  "valid": false,
  "error": "Token is invalid or expired"
}
```

**Error Response (400 Bad Request):**

```json
{
  "valid": false,
  "error": "Token is required"
}
```

---

### POST /password/reset

Reset password using the token from the email.

**Authentication:** None

**Request Body:**

```json
{
  "token": "abc123...",
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}
```

**Response (200 OK):**

```json
{
  "message": "Password reset successfully",
  "auth_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Error Responses:**

**400 Bad Request - Invalid Token:**

```json
{
  "error": "Invalid reset token"
}
```

**410 Gone - Expired Token:**

```json
{
  "error": "Reset token has expired"
}
```

**422 Unprocessable Entity - Invalid Password:**

```json
{
  "error": "Invalid password",
  "details": ["Password is too short (minimum is 6 characters)"]
}
```

---

## Onboarding Endpoints

### GET /onboarding/status

Get current onboarding status for authenticated user.

**Authentication:** Required (onboarding check skipped)

**Response (200 OK):**

```json
{
  "onboarding_completed": false,
  "role": null
}
```

For BAND accounts with primary band:

```json
{
  "onboarding_completed": true,
  "role": "band",
  "primary_band": {
    "id": 1,
    "slug": "the-band-name",
    "name": "The Band Name",
    "location": "New York",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "user_owned": true
  }
}
```

---

### POST /onboarding/account-type

Set account type (Step 1 of onboarding).

**Authentication:** Required (onboarding check skipped)

**Request Body:**

```json
{
  "role": "fan"
}
```

or

```json
{
  "role": "band"
}
```

**Response (200 OK):**

```json
{
  "message": "Account type set successfully",
  "role": "fan",
  "onboarding_completed": false,
  "next_step": "complete_fan_profile"
}
```

---

### POST /onboarding/complete-fan-profile

Complete FAN profile setup (Step 2 for FAN accounts).

**Authentication:** Required (onboarding check skipped)

**Request Body (multipart/form-data):**

```
username: "johndoe"
about_me: "Music lover from NYC" (optional)
profile_image: <file> (optional)
city: "Los Angeles" (optional)
region: "California" (optional)
```

**Response (200 OK):**

```json
{
  "message": "Fan profile completed successfully",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "about_me": "Music lover from NYC",
    "reviews_count": 0,
    "bands_count": 0,
    "lastfm_connected": false,
    "lastfm_username": null,
    "profile_image_url": "https://...",
    "role": "fan",
    "onboarding_completed": true,
    "display_name": "johndoe",
    "admin": false,
    "city": "Los Angeles",
    "region": "California",
    "location": "Los Angeles, California",
    "latitude": 34.0522,
    "longitude": -118.2437
  }
}
```

---

### POST /onboarding/complete-band-profile

Complete BAND profile setup (Step 2 for BAND accounts). Creates the primary band.

**Authentication:** Required (onboarding check skipped)

**Request Body (multipart/form-data):**

```
name: "The Band Name" (required)
about: "We make great music" (optional)
city: "New York" (optional)
region: "New York" (optional)
spotify_link: "https://open.spotify.com/artist/..." (optional)
bandcamp_link: "https://theband.bandcamp.com" (optional)
apple_music_link: "https://music.apple.com/..." (optional)
youtube_music_link: "https://music.youtube.com/..." (optional)
profile_picture: <file> (optional)
```

**Response (200 OK):**

```json
{
  "message": "Band profile completed successfully",
  "user": {
    "id": 1,
    "email": "band@example.com",
    "username": null,
    "about_me": null,
    "reviews_count": 0,
    "bands_count": 1,
    "lastfm_connected": false,
    "lastfm_username": null,
    "profile_image_url": null,
    "role": "band",
    "onboarding_completed": true,
    "display_name": "The Band Name",
    "admin": false,
    "primary_band": {
      "id": 1,
      "slug": "the-band-name",
      "name": "The Band Name",
      "location": "New York, New York",
      "profile_picture_url": "https://...",
      "reviews_count": 0,
      "user_owned": true
    }
  },
  "band": {
    "id": 1,
    "slug": "the-band-name",
    "name": "The Band Name",
    "city": "New York",
    "region": "New York",
    "location": "New York, New York",
    "latitude": 40.7128,
    "longitude": -74.006,
    "spotify_link": "https://open.spotify.com/artist/...",
    "bandcamp_link": "https://theband.bandcamp.com",
    "apple_music_link": null,
    "youtube_music_link": null,
    "musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
    "lastfm_artist_name": "Band Name",
    "lastfm_url": "https://www.last.fm/music/Band+Name",
    "about": "We make great music",
    "profile_picture_url": "https://...",
    "reviews_count": 0,
    "user_owned": true,
    "owner": { "id": 1, "username": null },
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
}
```

---

## User/Profile Endpoints

### GET /profile

Get current authenticated user's profile.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "johndoe",
  "about_me": "Music lover",
  "reviews_count": 10,
  "bands_count": 2,
  "lastfm_connected": true,
  "lastfm_username": "johndoe_lastfm",
  "profile_image_url": "https://...",
  "role": "fan",
  "onboarding_completed": true,
  "display_name": "johndoe",
  "admin": false,
  "city": "Los Angeles",
  "region": "California",
  "location": "Los Angeles, California",
  "latitude": 34.0522,
  "longitude": -118.2437,
  "followers_count": 25,
  "following_count": 12,
  "role": "fan",
  "plan": {
    "key": "fan_free",
    "name": "Fan Free"
  },
  "abilities": ["create_recommendation", "follow_users", "create_comments", "scrobble_lastfm"],
  "preferred_streaming_platform": "spotify",
  "allow_anonymous_comments": false,
  "social_links": {
    "instagram": "https://instagram.com/johndoe",
    "twitter": "https://twitter.com/johndoe"
  }
}
```

For BAND accounts:

```json
{
  "id": 1,
  "email": "band@example.com",
  "username": null,
  "about_me": null,
  "reviews_count": 0,
  "bands_count": 1,
  "lastfm_connected": false,
  "lastfm_username": null,
  "profile_image_url": null,
  "role": "band",
  "onboarding_completed": true,
  "display_name": "The Band Name",
  "admin": false,
  "city": null,
  "region": null,
  "location": null,
  "latitude": null,
  "longitude": null,
  "followers_count": 100,
  "following_count": 5,
  "role": "band",
  "plan": {
    "key": "band_starter",
    "name": "Band Starter"
  },
  "abilities": ["create_recommendation", "manage_storefront", "follow_users", "create_comments", "send_newsletter", "view_analytics", "manage_band_profile", "upload_music", "manage_events", "custom_design"],
  "preferred_streaming_platform": null,
  "allow_anonymous_comments": false,
  "social_links": {
    "instagram": "https://instagram.com/thebandname",
    "tiktok": "https://tiktok.com/@thebandname"
  },
  "primary_band": {
    "id": 1,
    "slug": "the-band-name",
    "name": "The Band Name",
    "location": "New York",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "user_owned": true
  }
}
```

---

### PATCH /profile

Update current user's profile.

**Authentication:** Required

**Request Body (multipart/form-data):**

```
about_me: "Updated bio"
profile_image: <file>
city: "Los Angeles"
region: "California"
preferred_streaming_platform: "spotify"
allow_anonymous_comments: true
instagram_url: "https://instagram.com/username"
threads_url: "https://threads.net/@username"
bluesky_url: "https://bsky.app/profile/username.bsky.social"
twitter_url: "https://twitter.com/username"
tumblr_url: "https://username.tumblr.com"
tiktok_url: "https://tiktok.com/@username"
facebook_url: "https://facebook.com/username"
youtube_url: "https://youtube.com/@username"
```

**Fields:**
- `about_me` (optional): User bio (max 500 characters)
- `profile_image` (optional): Profile image file
- `city` (optional): City name (max 100 characters)
- `region` (optional): State/province/country (max 100 characters)
- `preferred_streaming_platform` (optional): User's preferred streaming service. Valid values: `spotify`, `appleMusic`, `youtubeMusic`, `tidal`, `amazonMusic`, `deezer`, `soundcloud`, `bandcamp`. Set to `null` to clear preference.
- `allow_anonymous_comments` (optional): Whether to allow anonymous comments on the user's blog posts (default: false). Useful for bloggers who want guest engagement.

**Social Links (all optional):**
- `instagram_url`: Instagram profile URL (format: `https://instagram.com/...`)
- `threads_url`: Threads profile URL (format: `https://threads.net/@...`)
- `bluesky_url`: Bluesky profile URL (format: `https://bsky.app/profile/...`)
- `twitter_url`: Twitter/X profile URL (format: `https://twitter.com/...` or `https://x.com/...`)
- `tumblr_url`: Tumblr blog URL (format: `https://username.tumblr.com`)
- `tiktok_url`: TikTok profile URL (format: `https://tiktok.com/@...`)
- `facebook_url`: Facebook profile URL (format: `https://facebook.com/...`)
- `youtube_url`: YouTube channel URL (format: `https://youtube.com/...` or `https://youtu.be/...`)

Note: When city/region are provided, latitude and longitude are automatically calculated via geocoding. The `region` field can be used for US states (e.g., "California"), countries (e.g., "United Kingdom"), or provinces (e.g., "Ontario, Canada").

**Response (200 OK):**
Returns updated user profile (same format as GET /profile)

---

### POST /update-profile

Alias for PATCH /profile (for frontend compatibility).

---

### GET /users/:username

Get public profile for a user by username with paginated reviews. For blogger users, also includes paginated blog posts.

**Authentication:** None (optional - if authenticated, includes `following` field and `liked_by_current_user` for reviews)

**Query Parameters:**

- `page` (optional): Page number for reviews (default: 1)
- `per_page` (optional): Reviews per page (default: 20, max: 50)
- `posts_page` (optional): Page number for posts - blogger users only (default: 1)
- `posts_per_page` (optional): Posts per page - blogger users only (default: 10, max: 50)
- `tag` (optional): Filter posts by tag - blogger users only
- `category` (optional): Filter posts by category - blogger users only

**Response (200 OK):**

```json
{
  "id": 1,
  "username": "johndoe",
  "email": "user@example.com",
  "about_me": "Music lover",
  "profile_image_url": "https://...",
  "reviews_count": 10,
  "bands_count": 2,
  "role": "fan",
  "display_name": "johndoe",
  "location": "Los Angeles, California",
  "followers_count": 25,
  "following_count": 12,
  "allow_anonymous_comments": false,
  "following": true,
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "band_name": "Artist Name",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "band": { ... },
      "author": {
        "id": 1,
        "username": "johndoe",
        "profile_image_url": "https://..."
      },
      "likes_count": 5,
      "liked_by_current_user": true,
      "comments_count": 2,
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "reviews_pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 45,
    "total_pages": 3,
    "has_next_page": true,
    "has_previous_page": false
  },
  "bands": [
    {
      "id": 1,
      "slug": "band-name",
      "name": "Band Name",
      "location": "New York",
      "profile_picture_url": "https://...",
      "reviews_count": 5,
      "user_owned": true
    }
  ],
  "posts": [
    {
      "id": 1,
      "slug": "my-first-post",
      "title": "My First Post",
      "excerpt": "A short preview...",
      "featured_image_url": "https://...",
      "featured": false,
      "tags": ["music", "reviews"],
      "categories": ["opinion"],
      "authors": [
        { "name": "John Doe", "url": "https://example.com" }
      ],
      "publish_date": "2024-12-01T00:00:00.000Z",
      "created_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "posts_pagination": {
    "current_page": 1,
    "per_page": 10,
    "total_count": 5,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

**Notes:**
- The `following` field is only included if the request includes a valid authentication token
- The `liked_by_current_user` field on reviews reflects whether the authenticated user has liked each review
- The `posts` and `posts_pagination` fields are only included for blogger users
- Posts are ordered with featured posts first, then by publish date (newest first)

---

### GET /recently-played

Get user's recently played tracks aggregated from multiple sources (Last.fm, local scrobbles, etc.).

Tracks are merged from all connected sources, sorted by `played_at` (most recent first), and deduplicated. Consecutive plays of the same track within 5 minutes are collapsed into a single entry.

**Authentication:** Required

**Query Parameters:**

- `limit` (optional): Number of tracks to return (default: 20)
- `sources` (optional): Comma-separated list of sources to include. Valid values: `lastfm`, `scrobble`. If omitted, all connected sources are used.

**Examples:**

- `GET /recently-played` - All sources
- `GET /recently-played?limit=50` - All sources, 50 tracks
- `GET /recently-played?sources=lastfm` - Last.fm only
- `GET /recently-played?sources=scrobble` - Local scrobbles only
- `GET /recently-played?sources=lastfm,scrobble` - Both sources explicitly

**Response (200 OK):**

```json
{
  "tracks": [
    {
      "name": "Song Name",
      "artist": "Artist Name",
      "album": "Album Name",
      "played_at": "2024-12-01T00:00:00Z",
      "now_playing": false,
      "source": "lastfm",
      "mbid": "musicbrainz-track-id",
      "album_art_url": "https://...",
      "loved": true
    },
    {
      "name": "Another Song",
      "artist": "Another Artist",
      "album": "Another Album",
      "played_at": "2024-12-01T00:05:00Z",
      "now_playing": false,
      "source": "scrobble",
      "mbid": "musicbrainz-track-id",
      "album_art_url": "https://..."
    }
  ],
  "sources": ["lastfm", "scrobble"]
}
```

**Response Fields:**

- `tracks` - Array of recently played tracks, sorted by `played_at` descending
  - `name` - Track name
  - `artist` - Artist name
  - `album` - Album name (may be null)
  - `played_at` - ISO 8601 timestamp (null if `now_playing` is true)
  - `now_playing` - True if track is currently playing (Last.fm only)
  - `source` - Source of this track: `lastfm` or `scrobble`
  - `mbid` - MusicBrainz recording ID (may be null)
  - `album_art_url` - Album artwork URL (may be null, uses preferred artwork if set)
  - `loved` - True if track is loved on Last.fm (Last.fm only, omitted for scrobbles)
  - `scrobble_id` - Scrobble ID (scrobble source only, use for artwork updates)
  - `metadata_status` - Enrichment status: `pending`, `enriched`, `not_found`, `failed` (scrobble source only)
  - `has_preferred_artwork` - True if user has set custom artwork for this scrobble (scrobble source only)
- `sources` - Array of source names that were queried

**Notes:**

- If Last.fm is not connected, only local scrobbles are returned
- If no scrobbles exist and Last.fm is not connected, returns empty tracks array
- Tracks from different sources are interleaved based on `played_at` timestamp
- Deduplication: If the same track (by name + artist, case-insensitive) appears consecutively within 5 minutes, only the most recent entry is shown
- The `sources` array in the response shows which sources were actually queried (based on availability and filter)
- For scrobbles with `metadata_status: pending`, artwork is still being fetched - show a loading state in the UI
- Users can set custom artwork via `PATCH /api/v1/scrobbles/:id/artwork` using options from `GET /artwork/search`

---

## User Search Endpoint

### GET /users/search

Search for users by username prefix (for mention autocomplete).

**Authentication:** Required

**Query Parameters:**

- `q` (required): Username prefix to search (minimum 2 characters)

**Response (200 OK):**

```json
{
  "users": [
    {
      "id": 123,
      "username": "johndoe",
      "display_name": "John Doe",
      "profile_image_url": "https://..."
    },
    {
      "id": 456,
      "username": "johnsmith",
      "display_name": "John Smith",
      "profile_image_url": null
    }
  ]
}
```

**Notes:**
- Returns up to 10 matching users
- Excludes the current user from results
- Excludes disabled accounts
- Case-insensitive prefix matching

---

## Follow Endpoints

### POST /users/:user_id/follow

Follow a user.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Successfully followed johndoe",
  "following": true,
  "followers_count": 10,
  "following_count": 5
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You are already following this user"
}
```

---

### DELETE /users/:user_id/follow

Unfollow a user.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Successfully unfollowed johndoe",
  "following": false,
  "followers_count": 9,
  "following_count": 5
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You are not following this user"
}
```

---

### GET /following

Get list of users the current user is following.

**Authentication:** Required

**Response (200 OK):**

```json
[
  {
    "id": 2,
    "username": "janedoe",
    "display_name": "janedoe",
    "role": "fan",
    "profile_image_url": "https://...",
    "location": "Los Angeles, California",
    "following": true
  },
  {
    "id": 3,
    "username": null,
    "display_name": "The Band Name",
    "role": "band",
    "profile_image_url": "https://...",
    "location": "New York, New York",
    "following": true
  }
]
```

---

### GET /followers

Get list of users following the current user.

**Authentication:** Required

**Response (200 OK):**
Returns array of users (same format as GET /following)

---

### GET /users/:user_id/following

Get list of users a specific user is following.

**Authentication:** Required

**Response (200 OK):**
Returns array of users (same format as GET /following)

---

### GET /users/:user_id/followers

Get list of users following a specific user.

**Authentication:** Required

**Response (200 OK):**
Returns array of users (same format as GET /following)

---

## Profile Customization Endpoints

Profile customization allows paid band and blogger accounts to customize their public profiles with theming, sections, and layout ordering.

**Required Ability:** `can_customize_profile` (Band Starter, Band Pro, Blogger, Blogger Pro)

### GET /api/v1/profile_theme

Get the authenticated user's profile theme configuration including draft.

**Authentication:** Required + `can_customize_profile` ability

**Response (200 OK):**

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
    "sections": [
      { "type": "hero", "visible": true, "order": 0, "content": {} },
      { "type": "music", "visible": true, "order": 1, "content": {} },
      { "type": "events", "visible": true, "order": 2, "content": {} }
    ],
    "single_post_layout": {
      "show_featured_image": true,
      "show_author": true,
      "show_song_embed": true,
      "show_comments": true,
      "show_related_posts": true,
      "show_navigation": true,
      "content_layout": "default",
      "background_color": null,
      "font_color": null,
      "max_width": null
    },
    "draft_sections": null,
    "draft_single_post_layout": null,
    "has_draft": false,
    "published_at": "2026-03-02T10:30:00Z",
    "created_at": "2026-03-01T09:00:00Z",
    "updated_at": "2026-03-02T10:30:00Z",
    "config": {
      "approved_fonts": ["Inter", "Space Grotesk", "DM Sans", "..."],
      "section_types": ["hero", "music", "events", "posts", "about", "recommendations", "custom_text", "mailing_list", "merch"],
      "max_sections": 12,
      "max_custom_text": 3,
      "section_schemas": { "...see Section Schemas Reference..." },
      "social_link_types": ["instagram", "threads", "bluesky", "twitter", "tumblr", "tiktok", "facebook", "youtube"],
      "streaming_link_types": ["spotify", "appleMusic", "bandcamp", "soundcloud", "youtubeMusic"],
      "single_post_content_layouts": ["default", "wide", "narrow"],
      "single_post_layout_schema": {
        "show_featured_image": { "type": "boolean", "default": true },
        "show_author": { "type": "boolean", "default": true },
        "show_song_embed": { "type": "boolean", "default": true },
        "show_comments": { "type": "boolean", "default": true },
        "show_related_posts": { "type": "boolean", "default": true },
        "show_navigation": { "type": "boolean", "default": true },
        "content_layout": { "type": "enum", "options": ["default", "wide", "narrow"], "default": "default" },
        "background_color": { "type": "color", "optional": true, "description": "Inherits from theme if null" },
        "font_color": { "type": "color", "optional": true, "description": "Inherits from theme if null" },
        "max_width": { "type": "integer", "min": 600, "max": 1600, "optional": true, "description": "Inherits from theme if null" }
      }
    },
    "source_data": {
      "display_name": "The Midnight Pines",
      "location": "Portland, OR",
      "about_text": "We are an indie rock band from Portland.",
      "profile_image_url": "https://...",
      "social_links": {
        "instagram": "https://instagram.com/midnightpines",
        "twitter": "https://twitter.com/midnightpines"
      },
      "user": {
        "id": 42,
        "username": "midnightpines",
        "role": "band"
      },
      "band": {
        "id": 5,
        "slug": "midnight-pines",
        "name": "The Midnight Pines",
        "location": "Portland, OR",
        "about": "We are an indie rock band from Portland.",
        "profile_picture_url": "https://..."
      },
      "streaming_links": {
        "spotify": "https://open.spotify.com/artist/...",
        "bandcamp": "https://midnightpines.bandcamp.com"
      },
      "posts": [
        { "id": 1, "title": "New Album Announcement", "slug": "new-album", "...": "..." }
      ],
      "recommendations": [
        { "id": 10, "content": "Amazing track!", "track": { "...": "..." }, "...": "..." }
      ],
      "events": [
        { "id": 3, "name": "Live at The Doug Fir", "event_date": "2026-04-15T20:00:00Z", "...": "..." }
      ],
      "sample_post": {
        "id": 1,
        "title": "New Album Announcement",
        "slug": "new-album",
        "body": "<p>Full post body...</p>",
        "...": "...",
        "comments": [
          { "id": 1, "body": "Great post!", "author": { "username": "fan1", "...": "..." }, "...": "..." }
        ],
        "related_posts": [
          { "id": 2, "title": "Tour Dates Announced", "slug": "tour-dates", "...": "..." }
        ],
        "navigation": {
          "next_post": { "title": "Newer Post", "slug": "newer-post" },
          "previous_post": { "title": "Older Post", "slug": "older-post" }
        }
      }
    }
  }
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "can_customize_profile",
  "upgrade_plan": "band_starter"
}
```

**Notes:**
- Returns default theme if none exists
- `config` contains static configuration for frontend reference
- `draft_sections` contains unpublished section changes (null if no draft)
- `draft_single_post_layout` contains unpublished single post layout changes (null if no draft)
- `single_post_layout` is the published layout merged with defaults (all fields always present)
- `source_data` contains the actual user/band data for site builder previews (see below)

**Using source_data for Site Builder:**

The `source_data` object provides the actual profile data that sections will display. Use it to:

1. **Show default values in the editor** - When a section's content field has a `source` (e.g., `headline: { source: "display_name" }`), display `source_data.display_name` as the default/placeholder
2. **Preview sections accurately** - Render the hero section showing `source_data.display_name` unless the user has provided custom `content.headline`
3. **Show available links** - Display `source_data.social_links` and `source_data.streaming_links` so users can choose which to show/hide
4. **Preview dynamic sections** - Use `source_data.posts`, `source_data.recommendations`, and `source_data.events` to preview content sections in the site builder
5. **Preview single post page** - Use `source_data.sample_post` to render a preview of the single post layout in the site builder, including comments, related posts, and navigation

| source_data field | Used by | Schema source reference |
|-------------------|---------|------------------------|
| `display_name` | Hero headline | `source: "display_name"` |
| `location` | Hero subtitle | `source: "location"` |
| `about_text` | About bio | `source: "about_text"` |
| `profile_image_url` | Hero image | - |
| `social_links` | Hero, About | `visible_social_links` setting |
| `streaming_links` | Hero, Music | `visible_streaming_links` setting |
| `posts` | Posts section | Up to 10 recent published posts |
| `recommendations` | Recommendations section | Up to 10 recent reviews |
| `events` | Events section | Up to 10 upcoming active events |
| `sample_post` | Single post layout preview | Latest published post with comments, related posts, and navigation |
| `band` | Band users only | Band profile data |

---

### PUT /api/v1/profile_theme

Update the profile theme. Section and single post layout changes go to draft and must be published separately.

**Authentication:** Required + `can_customize_profile` ability

**Request Body:**

```json
{
  "background_color": "#1a1a1a",
  "brand_color": "#ff6b35",
  "font_color": "#f0f0f0",
  "header_font": "Space Grotesk",
  "body_font": "Inter",
  "sections": [
    {
      "type": "hero",
      "visible": true,
      "order": 0,
      "content": { "headline": "Welcome to our page" },
      "settings": {
        "show_profile_image": true,
        "visible_streaming_links": ["spotify", "bandcamp"],
        "visible_social_links": ["instagram", "twitter"]
      }
    },
    {
      "type": "music",
      "visible": true,
      "order": 1,
      "settings": { "display_limit": 6 }
    },
    {
      "type": "events",
      "visible": true,
      "order": 2,
      "settings": { "display_limit": 4, "show_past_events": false }
    },
    {
      "type": "about",
      "visible": true,
      "order": 3,
      "content": { "bio": "About us..." },
      "settings": { "show_social_links": true }
    }
  ],
  "single_post_layout": {
    "show_featured_image": true,
    "show_author": true,
    "show_song_embed": true,
    "show_comments": true,
    "show_related_posts": false,
    "show_navigation": true,
    "content_layout": "wide"
  }
}
```

**Response (200 OK):**

```json
{
  "data": {
    "id": 1,
    "background_color": "#1a1a1a",
    "brand_color": "#ff6b35",
    "sections": [...],
    "draft_sections": [...],
    "has_draft": true,
    "...": "..."
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "validation_error",
  "message": "Cannot have more than 12 sections, hero section can only appear once",
  "details": [
    "Cannot have more than 12 sections",
    "hero section can only appear once"
  ]
}
```

**Notes:**
- Global theme fields (colors, fonts) are updated immediately
- Section changes go to `draft_sections` until published
- `single_post_layout` changes go to `draft_single_post_layout` until published
- Only include the fields you want to override in `single_post_layout` — omitted fields keep their current values
- Color fields must be valid hex colors (e.g., `#FF5733`)
- Fonts must be from the approved list

---

### POST /api/v1/profile_theme/publish

Publish draft sections and/or draft single post layout to make them live on the public profile.

**Authentication:** Required + `can_customize_profile` ability

**Response (200 OK):**

```json
{
  "data": {
    "id": 1,
    "sections": [...],
    "draft_sections": null,
    "has_draft": false,
    "published_at": "2026-03-02T15:00:00Z",
    "...": "..."
  },
  "message": "Theme published successfully"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "no_draft",
  "message": "No draft to publish"
}
```

---

### POST /api/v1/profile_theme/discard_draft

Discard unpublished draft sections and draft single post layout.

**Authentication:** Required + `can_customize_profile` ability

**Response (200 OK):**

```json
{
  "data": {
    "id": 1,
    "sections": [...],
    "draft_sections": null,
    "has_draft": false,
    "...": "..."
  },
  "message": "Draft discarded"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "no_draft",
  "message": "No draft to discard"
}
```

---

### POST /api/v1/profile_theme/reset

Reset the theme to role-based defaults (colors, fonts, and sections).

**Authentication:** Required + `can_customize_profile` ability

**Response (200 OK):**

```json
{
  "data": {
    "id": 1,
    "background_color": "#121212",
    "brand_color": "#6366f1",
    "font_color": "#f5f5f5",
    "header_font": "Inter",
    "body_font": "Inter",
    "sections": [...],
    "draft_sections": null,
    "has_draft": false,
    "published_at": null,
    "...": "..."
  },
  "message": "Theme reset to defaults"
}
```

---

### GET /api/v1/profile_assets

List the authenticated user's uploaded profile assets (background images, etc.).

**Authentication:** Required + `can_customize_profile` ability

**Response (200 OK):**

```json
{
  "data": [
    {
      "id": 1,
      "purpose": "background",
      "url": "https://api.goodsongs.app/rails/active_storage/blobs/.../image.jpg",
      "thumbnail_url": "https://api.goodsongs.app/rails/active_storage/representations/.../image.jpg",
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

---

### POST /api/v1/profile_assets

Upload a new profile asset image.

**Authentication:** Required + `can_customize_profile` ability

**Content-Type:** `multipart/form-data`

**Request Body:**

- `image` (required): Image file (JPEG, PNG, or WebP, max 5MB)
- `purpose` (optional): Asset purpose - `"background"`, `"header"`, or `"custom"` (default: `"background"`)

**Response (201 Created):**

```json
{
  "data": {
    "id": 2,
    "purpose": "background",
    "url": "https://api.goodsongs.app/rails/active_storage/blobs/.../new-image.jpg",
    "thumbnail_url": "https://api.goodsongs.app/rails/active_storage/representations/.../new-image.jpg",
    "file_type": "image/png",
    "file_size": 180000,
    "created_at": "2026-03-02T14:00:00Z"
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "validation_error",
  "message": "Image must be less than 5MB, Image must be a JPEG, PNG, or WebP image",
  "details": {
    "image": ["must be less than 5MB", "must be a JPEG, PNG, or WebP image"]
  }
}
```

**Notes:**
- Maximum 20 assets per user
- Maximum file size: 5MB
- Allowed types: JPEG, PNG, WebP

---

### DELETE /api/v1/profile_assets/:id

Delete a profile asset.

**Authentication:** Required + `can_customize_profile` ability

**URL Parameters:**

- `id` (required): The asset ID

**Response (200 OK):**

```json
{
  "message": "Asset deleted successfully"
}
```

**Error Response (404 Not Found):**

```json
{
  "error": "not_found",
  "message": "Asset not found"
}
```

---

### GET /api/v1/profiles/:username

Get a user's public profile with theme and hydrated section data. This is the public-facing profile endpoint.

**Authentication:** None required

**URL Parameters:**

- `username` (required): The user's username

**Response (200 OK):**

```json
{
  "data": {
    "user": {
      "id": 42,
      "username": "midnightpines",
      "email": "band@example.com",
      "about_me": "We are a band from Portland.",
      "profile_image_url": "https://...",
      "reviews_count": 15,
      "role": "band",
      "display_name": "The Midnight Pines",
      "location": "Portland, OR",
      "followers_count": 1200,
      "following_count": 50,
      "primary_band": {
        "id": 5,
        "slug": "midnight-pines",
        "name": "The Midnight Pines",
        "location": "Portland, OR",
        "profile_picture_url": "https://..."
      }
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
        "content": {
          "headline": "The Midnight Pines",
          "subtitle": "Portland, OR"
        },
        "settings": {
          "show_profile_image": true,
          "visible_streaming_links": ["spotify", "bandcamp"],
          "visible_social_links": ["instagram", "twitter"]
        },
        "data": {
          "display_name": "The Midnight Pines",
          "profile_image_url": "https://...",
          "location": "Portland, OR",
          "streaming_links": {
            "spotify": "https://open.spotify.com/artist/...",
            "bandcamp": "https://midnightpines.bandcamp.com"
          },
          "social_links": {
            "instagram": "https://instagram.com/midnightpines",
            "twitter": "https://twitter.com/midnightpines"
          },
          "band": { "id": 5, "slug": "midnight-pines", "name": "The Midnight Pines" }
        }
      },
      {
        "type": "music",
        "order": 1,
        "content": {},
        "settings": { "display_limit": 6 },
        "data": {
          "band": { "...": "..." },
          "tracks": [{ "id": 1, "name": "Song Title", "...": "..." }],
          "bandcamp_embed": "<iframe>...</iframe>",
          "streaming_links": { "spotify": "...", "bandcamp": "..." }
        }
      },
      {
        "type": "events",
        "order": 2,
        "content": {},
        "settings": { "display_limit": 6, "show_past_events": false },
        "data": {
          "events": [
            { "id": 1, "name": "Live at The Fillmore", "event_date": "2026-04-15", "...": "..." }
          ]
        }
      },
      {
        "type": "posts",
        "order": 3,
        "content": {},
        "settings": { "display_limit": 6 },
        "data": {
          "posts": [
            { "id": 1, "title": "New Album Announcement", "slug": "new-album", "...": "..." }
          ]
        }
      }
    ]
  }
}
```

**Response (404 Not Found):**

```json
{
  "error": "not_found",
  "message": "User not found"
}
```

**Notes:**
- Returns only visible sections
- Filters out sections the user's plan doesn't support (mailing_list, merch)
- Each section includes hydrated `data` with pre-fetched content
- Fan accounts return basic profile without customization
- If no theme exists, returns default sections based on user role

---

### GET /api/v1/profiles/bands/:slug/posts/:post_slug

Get a single blog post wrapped in the band's profile theme. Used for themed single post pages.

**Authentication:** None required

**URL Parameters:**

- `slug` (required): The band's URL slug
- `post_slug` (required): The post's URL slug

**Response (200 OK):**

```json
{
  "data": {
    "post": {
      "id": 1,
      "title": "New Album Announcement",
      "slug": "new-album",
      "body": "<p>Full post body...</p>",
      "excerpt": "Short summary...",
      "featured_image_url": "https://...",
      "publish_date": "2026-03-01T12:00:00Z",
      "song": { "name": "Track Name", "band_name": "Artist", "...": "..." },
      "author": { "username": "midnightpines", "display_name": "The Midnight Pines", "...": "..." },
      "likes_count": 12,
      "comments_count": 5,
      "...": "..."
    },
    "user": {
      "id": 42,
      "username": "midnightpines",
      "display_name": "The Midnight Pines",
      "role": "band",
      "primary_band": { "id": 5, "slug": "midnight-pines", "name": "The Midnight Pines" },
      "...": "..."
    },
    "theme": {
      "background_color": "#121212",
      "brand_color": "#6366f1",
      "font_color": "#f5f5f5",
      "header_font": "Inter",
      "body_font": "Inter",
      "content_max_width": 1200,
      "single_post_layout": {
        "show_featured_image": true,
        "show_author": true,
        "show_song_embed": true,
        "show_comments": true,
        "show_related_posts": true,
        "show_navigation": true,
        "content_layout": "default",
        "background_color": null,
        "font_color": null,
        "max_width": null
      }
    },
    "comments": {
      "data": [
        {
          "id": 1,
          "body": "Great post!",
          "anonymous": false,
          "likes_count": 3,
          "author": { "id": 99, "username": "fan1", "display_name": "Fan One", "profile_image_url": "https://..." },
          "created_at": "2026-03-01T14:00:00Z",
          "updated_at": "2026-03-01T14:00:00Z"
        }
      ],
      "pagination": {
        "current_page": 1,
        "total_count": 42,
        "total_pages": 3,
        "per_page": 20
      }
    },
    "related_posts": [
      { "id": 2, "title": "Tour Dates Announced", "slug": "tour-dates", "...": "..." }
    ],
    "navigation": {
      "next_post": { "title": "Newer Post Title", "slug": "newer-post" },
      "previous_post": { "title": "Older Post Title", "slug": "older-post" }
    }
  }
}
```

**Response (404 Not Found):**

```json
{
  "error": "not_found",
  "message": "Post not found"
}
```

**Notes:**
- `comments`, `related_posts`, and `navigation` are conditionally included based on the `single_post_layout` toggles
- If `show_comments` is `false`, `comments` is omitted from the response
- If `show_related_posts` is `false`, `related_posts` is omitted
- If `show_navigation` is `false`, `navigation` is omitted
- If no theme exists, `theme` is `null` and all defaults are used (all toggles on)
- Comments do not include `liked_by_current_user` (no auth on public endpoint)
- Comments are paginated (20 per page, first page only)

---

### GET /api/v1/profiles/users/:username/posts/:post_slug

Get a single blog post wrapped in the user's profile theme. Same response shape as the band post endpoint above.

**Authentication:** None required

**URL Parameters:**

- `username` (required): The user's username
- `post_slug` (required): The post's URL slug

**Response:** Same as `GET /api/v1/profiles/bands/:slug/posts/:post_slug`

---

### Single Post Layout Reference

The `single_post_layout` controls how individual blog post pages are rendered. It follows the same draft/publish workflow as sections.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `show_featured_image` | boolean | `true` | Show the post's featured image |
| `show_author` | boolean | `true` | Show the post author info |
| `show_song_embed` | boolean | `true` | Show the linked song embed |
| `show_comments` | boolean | `true` | Show comments section |
| `show_related_posts` | boolean | `true` | Show related posts from the same author |
| `show_navigation` | boolean | `true` | Show prev/next post navigation |
| `content_layout` | enum | `"default"` | `"default"`, `"wide"`, or `"narrow"` |
| `background_color` | color/null | `null` | Override theme background (null = inherit) |
| `font_color` | color/null | `null` | Override theme font color (null = inherit) |
| `max_width` | integer/null | `null` | Override content max width, 600-1600 (null = inherit) |

---

### Section Types Reference

| Section Type | Description | Plan Availability |
|--------------|-------------|-------------------|
| `hero` | Profile header with name, image, location | All paid plans |
| `music` | Band's tracks and music embeds | All paid plans |
| `events` | Upcoming events list | All paid plans |
| `posts` | Blog posts list | All paid plans |
| `about` | About text/bio section | All paid plans |
| `recommendations` | User's song recommendations/reviews | All paid plans |
| `custom_text` | Custom text blocks (up to 3) | All paid plans |
| `mailing_list` | Newsletter signup form | Band Pro, Blogger Pro |
| `merch` | Merchandise links | Band Pro only |

---

### Approved Fonts

Inter, Space Grotesk, DM Sans, Plus Jakarta Sans, Outfit, Sora, Manrope, Rubik, Work Sans, Nunito Sans, Lora, Merriweather, Playfair Display, Source Serif 4, Libre Baskerville, IBM Plex Mono, JetBrains Mono

---

### Section Schemas Reference

Each section type has defined `content` and `settings` fields. Content fields override profile-derived data, while settings control display behavior.

#### Hero Section

**Content Fields:**
| Field | Max Length | Description |
|-------|------------|-------------|
| `headline` | 120 | Override display name (source: user display_name) |
| `subtitle` | 200 | Override location text (source: user/band location) |
| `cta_text` | 40 | Call-to-action button text |
| `cta_url` | URL | Call-to-action button link |

**Settings:**
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `background_color` | hex color | - | Section background color override |
| `show_profile_image` | boolean | true | Show/hide profile image |
| `visible_streaming_links` | array | `:configured` | Which streaming links to show (see Link Visibility) |
| `visible_social_links` | array | `:configured` | Which social links to show (see Link Visibility) |

#### Music Section

**Content Fields:** None (data hydrated from band)

**Settings:**
| Field | Type | Default | Range | Description |
|-------|------|---------|-------|-------------|
| `display_limit` | integer | 6 | 1-24 | Number of tracks to display |

#### Events Section

**Content Fields:** None (data hydrated from user's events)

**Settings:**
| Field | Type | Default | Range | Description |
|-------|------|---------|-------|-------------|
| `display_limit` | integer | 6 | 1-24 | Number of events to display |
| `show_past_events` | boolean | false | - | Include past events |

#### Posts Section

**Content Fields:** None (data hydrated from user)

**Settings:**
| Field | Type | Default | Range | Description |
|-------|------|---------|-------|-------------|
| `display_limit` | integer | 6 | 1-24 | Number of posts to display |

#### About Section

**Content Fields:**
| Field | Max Length | Description |
|-------|------------|-------------|
| `bio` | 2000 | Override bio text (source: band about or user about_me) |

**Settings:**
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `show_social_links` | boolean | true | Show social links in about section |
| `visible_social_links` | array | `:configured` | Which social links to show |

#### Recommendations Section

**Content Fields:** None (data hydrated from user reviews)

**Settings:**
| Field | Type | Default | Range | Description |
|-------|------|---------|-------|-------------|
| `display_limit` | integer | 12 | 1-24 | Number of recommendations to display |

#### Custom Text Section

**Content Fields:**
| Field | Max Length | Description |
|-------|------------|-------------|
| `title` | 120 | Section heading |
| `body` | 5000 | Main text content |

**Settings:**
| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `text_align` | enum | left, center, right | Text alignment |
| `background_color` | hex color | - | Section background color |

#### Mailing List Section (Pro Plans)

**Content Fields:**
| Field | Max Length | Description |
|-------|------------|-------------|
| `heading` | 120 | Section heading |
| `description` | 500 | Signup prompt text |

**Settings:**
| Field | Type | Description |
|-------|------|-------------|
| `provider_url` | URL | External mailing list provider URL |

#### Merch Section (Band Pro)

**Content Fields:**
| Field | Max Length | Description |
|-------|------------|-------------|
| `heading` | 120 | Section heading |

**Settings:**
| Field | Type | Description |
|-------|------|-------------|
| `store_url` | URL | External merch store URL |

---

### Link Visibility Settings

The `visible_streaming_links` and `visible_social_links` settings control which links are shown:

| Value | Behavior |
|-------|----------|
| `null` or `:configured` | Show all configured links (default) |
| `[]` (empty array) | Show no links |
| `["spotify", "bandcamp"]` | Show only specified link types |

**Streaming Link Types:** `spotify`, `appleMusic`, `bandcamp`, `soundcloud`, `youtubeMusic`

**Social Link Types:** `instagram`, `threads`, `bluesky`, `twitter`, `tumblr`, `tiktok`, `facebook`, `youtube`

**Example - Show only Spotify and Instagram:**
```json
{
  "type": "hero",
  "visible": true,
  "order": 0,
  "settings": {
    "visible_streaming_links": ["spotify"],
    "visible_social_links": ["instagram"]
  }
}
```

**Example - Hide all social links:**
```json
{
  "type": "hero",
  "visible": true,
  "order": 0,
  "settings": {
    "visible_social_links": []
  }
}
```

**Note:** Links are only shown if the user/band has them configured. The visibility setting filters the configured links; it cannot add links that don't exist.

---

## Profile Links Endpoints

Manage custom links displayed on a user's link page (Linktree-style). Requires `can_customize_profile` ability.

### GET /api/v1/profile_links

List all of the authenticated user's custom links, ordered by position.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "data": [
    {
      "id": 1,
      "title": "My Website",
      "url": "https://example.com",
      "icon": "link",
      "description": "My personal website and portfolio",
      "position": 0,
      "visible": true,
      "thumbnail_url": "https://api.goodsongs.app/rails/active_storage/blobs/...",
      "created_at": "2026-03-16T00:00:00.000Z",
      "updated_at": "2026-03-16T00:00:00.000Z"
    }
  ]
}
```

---

### POST /api/v1/profile_links

Create a new custom link. Supports both JSON and multipart/form-data (for thumbnail upload).

**Authentication:** Required

**Request Body (JSON):**

```json
{
  "title": "My Website",
  "url": "https://example.com",
  "icon": "link",
  "position": 0,
  "visible": true
}
```

**Request Body (multipart/form-data for thumbnail upload):**

```
title: "My Website"
url: "https://example.com"
icon: "link"
thumbnail: <file>
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Link title (max 100 characters) |
| `url` | string | Yes | Link URL (must start with http:// or https://) |
| `icon` | string | No | Icon identifier (e.g., "music", "shop", "link") |
| `description` | string | No | Short description of the link (max 200 characters) |
| `position` | integer | No | Display order (auto-assigned if omitted) |
| `visible` | boolean | No | Whether link is publicly visible (default: true) |
| `thumbnail` | file | No | Link thumbnail image (JPEG, PNG, or WebP, max 2MB) |

**Response (201 Created):**

```json
{
  "data": {
    "id": 1,
    "title": "My Website",
    "url": "https://example.com",
    "icon": "link",
    "position": 0,
    "visible": true,
    "thumbnail_url": "https://api.goodsongs.app/rails/active_storage/blobs/...",
    "created_at": "2026-03-16T00:00:00.000Z",
    "updated_at": "2026-03-16T00:00:00.000Z"
  }
}
```

---

### PUT /api/v1/profile_links/:id

Update an existing custom link. Supports both JSON and multipart/form-data (for thumbnail upload).

**Authentication:** Required

**Request Body:** Same fields as POST (all optional). Additionally:

| Field | Type | Description |
|-------|------|-------------|
| `thumbnail` | file | Replace thumbnail image (JPEG, PNG, or WebP, max 2MB) |
| `remove_thumbnail` | boolean | Set to `true` to remove the existing thumbnail |

**Response (200 OK):** Same shape as POST response.

---

### DELETE /api/v1/profile_links/:id

Delete a custom link.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Link deleted"
}
```

---

### PUT /api/v1/profile_links/reorder

Batch update positions for all links. The order of IDs in the array determines the new position values.

**Authentication:** Required

**Request Body:**

```json
{
  "link_ids": [3, 1, 2]
}
```

**Response (200 OK):**

```json
{
  "data": [
    { "id": 3, "title": "Third Link", "position": 0, "..." : "..." },
    { "id": 1, "title": "First Link", "position": 1, "..." : "..." },
    { "id": 2, "title": "Second Link", "position": 2, "..." : "..." }
  ]
}
```

---

## Profile Theme Pages

The profile theme now supports a `pages` concept alongside `sections`. Pages follow the same draft/publish workflow. The first page type is `links` (a Linktree-style page).

### Pages in Profile Theme Update

When updating the profile theme via `PUT /api/v1/profile_theme`, you can include a `pages` array. Pages are saved to `draft_pages` and promoted to `pages` on publish.

**Pages array format:**

```json
{
  "pages": [
    {
      "type": "links",
      "slug": "links",
      "visible": true,
      "settings": {
        "heading": "My Links",
        "description": "Find me everywhere",
        "show_social_links": true,
        "show_streaming_links": true,
        "layout": "list"
      }
    }
  ]
}
```

**Page fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Page type (currently only `links`) |
| `slug` | string | Yes | URL slug for the page |
| `visible` | boolean | Yes | Whether the page is publicly accessible |
| `settings` | object | No | Type-specific settings |

**Links page settings:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `heading` | string | null | Page heading (max 120 characters) |
| `description` | string | null | Page description (max 500 characters) |
| `show_social_links` | boolean | true | Show social platform links |
| `show_streaming_links` | boolean | true | Show streaming platform links |
| `layout` | string | "list" | Layout style: `list` or `grid` |

### Pages in Profile Theme Response

The `GET /api/v1/profile_theme` response now includes:

- `pages` — published pages array
- `draft_pages` — draft pages array (when `include_draft` is true)
- `config.page_types` — available page types
- `config.page_schemas` — settings schema for each page type
- `source_data.profile_links` — user's custom links for preview

The public theme serializer (`ProfileThemeSerializer.public`) also includes `pages`.

---

## Public Link Page Endpoints

Public endpoints to view a user's link page. No authentication required.

### GET /api/v1/profiles/bands/:slug/links

Get a band's public link page.

**Authentication:** None

**Response (200 OK):**

```json
{
  "data": {
    "user": { "...": "standard public_profile shape" },
    "theme": {
      "background_color": "#121212",
      "brand_color": "#6366f1",
      "font_color": "#f5f5f5",
      "header_font": "Inter",
      "body_font": "Inter",
      "content_max_width": 1200,
      "card_background_color": null,
      "card_background_opacity": 10,
      "single_post_layout": { "..." : "..." },
      "pages": [{ "type": "links", "slug": "links", "visible": true, "settings": {} }]
    },
    "page_settings": {
      "heading": "My Links",
      "description": "Find me everywhere",
      "show_social_links": true,
      "show_streaming_links": true,
      "layout": "list"
    },
    "profile": {
      "display_name": "Band Name",
      "about": "About the band",
      "profile_image_url": "https://...",
      "location": "City, State"
    },
    "custom_links": [
      {
        "id": 1,
        "title": "Our Merch Store",
        "description": "T-shirts, vinyl, and more",
        "url": "https://merch.example.com",
        "icon": "shop",
        "position": 0,
        "thumbnail_url": "https://api.goodsongs.app/rails/active_storage/blobs/..."
      }
    ],
    "social_links": {
      "instagram": "https://instagram.com/band",
      "twitter": "https://twitter.com/band"
    },
    "streaming_links": {
      "spotify": "https://open.spotify.com/artist/...",
      "bandcamp": "https://band.bandcamp.com"
    }
  }
}
```

**Error (404 Not Found):** Returned if the band doesn't exist or doesn't have a visible links page.

---

### GET /api/v1/profiles/users/:username/links

Get a user's (blogger) public link page. Same response shape as the band link page endpoint, but `streaming_links` will be empty for non-band users.

**Authentication:** None

**Response:** Same shape as `GET /api/v1/profiles/bands/:slug/links`.

**Error (404 Not Found):** Returned if the user doesn't exist or doesn't have a visible links page.

---

## Review Endpoints

### GET /reviews

Get all reviews (paginated, most recent first).

**Authentication:** Required

**Response (200 OK):**

```json
[
  {
    "id": 1,
    "song_link": "https://open.spotify.com/track/...",
    "band_name": "Artist Name",
    "song_name": "Song Title",
    "artwork_url": "https://...",
    "review_text": "Great song!",
    "liked_aspects": ["melody", "lyrics"],
    "band": {
      "id": 1,
      "slug": "artist-name",
      "name": "Artist Name",
      "city": null,
      "region": null,
      "location": null,
      "latitude": null,
      "longitude": null,
      "spotify_link": null,
      "bandcamp_link": null,
      "apple_music_link": null,
      "youtube_music_link": null,
      "about": null,
      "profile_picture_url": null,
      "reviews_count": 5,
      "user_owned": false,
      "owner": null,
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    },
    "author": {
      "id": 1,
      "username": "johndoe",
      "profile_image_url": "https://..."
    },
    "likes_count": 5,
    "liked_by_current_user": false,
    "comments_count": 3,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
]
```

---

### GET /reviews/:id

Get a single review by ID.

**Authentication:** None (optional - if authenticated, `liked_by_current_user` reflects the current user's like status)

**Response (200 OK):**

```json
{
  "id": 1,
  "song_link": "https://open.spotify.com/track/...",
  "band_name": "Artist Name",
  "song_name": "Song Title",
  "artwork_url": "https://...",
  "review_text": "Great song!",
  "liked_aspects": ["melody", "lyrics"],
  "genres": ["Alternative", "Art Rock"],
  "track": {
    "id": "uuid-here",
    "name": "Song Title",
    "album": {
      "id": "album-uuid",
      "name": "Album Name"
    },
    "source": "musicbrainz"
  },
  "band": {
    "id": 1,
    "slug": "artist-name",
    "name": "Artist Name",
    "city": null,
    "region": null,
    "location": null,
    "latitude": null,
    "longitude": null,
    "spotify_link": null,
    "bandcamp_link": null,
    "bandcamp_embed": null,
    "apple_music_link": null,
    "youtube_music_link": null,
    "musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
    "lastfm_artist_name": "Artist Name",
    "lastfm_url": "https://www.last.fm/music/Artist+Name",
    "about": null,
    "profile_picture_url": null,
    "reviews_count": 5,
    "user_owned": false,
    "owner": null,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  },
  "author": {
    "id": 1,
    "username": "johndoe",
    "profile_image_url": "https://..."
  },
  "likes_count": 5,
  "liked_by_current_user": false,
  "comments_count": 3,
  "created_at": "2024-12-01T00:00:00.000Z",
  "updated_at": "2024-12-01T00:00:00.000Z"
}
```

**Error Response (404 Not Found):**

```json
{
  "error": "Record not found"
}
```

---

### POST /reviews

Create a new review.

**Authentication:** Required

**Request Body:**

```json
{
  "review": {
    "song_link": "https://open.spotify.com/track/...",
    "band_name": "Artist Name",
    "song_name": "Song Title",
    "artwork_url": "https://...",
    "review_text": "Great song!",
    "liked_aspects": ["melody", "lyrics", "production"],
    "genres": ["Alternative", "Art Rock"],
    "band_musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
    "band_lastfm_artist_name": "Artist Name"
  }
}
```

**Fields:**

- `song_link` (optional): Link to the song on streaming platforms
- `band_name` (required): Artist/band name
- `song_name` (required): Track title
- `artwork_url` (optional): Album artwork URL
- `review_text` (required): Review content
- `liked_aspects` (optional): Array of aspects the reviewer liked (e.g., "melody", "lyrics", "production")
- `genres` (optional): Array of genre tags. Suggested values: Rock, Pop, Hip-Hop, Jazz, Blues, Country, R&B, Soul, Funk, Electronic, Metal, Punk, Indie, Alternative, Folk, Classical, Reggae, Latin, Ambient, Experimental. Custom genres are also allowed.
- `band_musicbrainz_id` (optional): MusicBrainz artist ID for metadata enrichment
- `band_lastfm_artist_name` (optional): Last.fm artist name for metadata enrichment

**Track Linking:**
When a review is created, the system automatically links it to an existing track or creates a new user-submitted track:

1. First, attempts an exact case-insensitive match on the band's existing tracks
2. If no exact match, uses fuzzy matching (PostgreSQL trigram similarity >0.6)
3. If no match found, creates a new user-submitted track linked to the band

**Streaming Links:**
The `track` object includes `streaming_links` and `songlink_url` fields that provide links to listen to the track on various streaming platforms. Supported platforms: spotify, appleMusic, youtubeMusic, tidal, amazonMusic, deezer, soundcloud, bandcamp. Links are fetched asynchronously using the Odesli (song.link) API based on the track's ISRC code.

**Response (201 Created):**
Returns created review object including `genres` array and `track` object (if linked)

**Example with User Mention:**

Request:
```json
{
  "review": {
    "band_name": "Radiohead",
    "song_name": "Karma Police",
    "review_text": "Amazing track! @johndoe you need to hear this",
    "genres": ["Alternative", "Art Rock"]
  }
}
```

Response:
```json
{
  "id": 123,
  "song_link": null,
  "band_name": "Radiohead",
  "song_name": "Karma Police",
  "artwork_url": null,
  "review_text": "Amazing track! @johndoe you need to hear this",
  "formatted_review_text": "Amazing track! [@johndoe](user:456) you need to hear this",
  "mentions": [
    {
      "user_id": 456,
      "username": "johndoe",
      "display_name": "John Doe"
    }
  ],
  "liked_aspects": [],
  "genres": ["Alternative", "Art Rock"],
  "track": {
    "id": "uuid-here",
    "name": "Karma Police",
    "album": null,
    "source": "user_submitted",
    "streaming_links": {
      "spotify": "https://open.spotify.com/track/...",
      "appleMusic": "https://music.apple.com/us/album/...",
      "youtubeMusic": "https://music.youtube.com/watch?v=...",
      "tidal": "https://tidal.com/track/..."
    },
    "songlink_url": "https://song.link/..."
  },
  "band": { ... },
  "author": { ... },
  "likes_count": 0,
  "liked_by_current_user": false,
  "comments_count": 0,
  "created_at": "2024-12-01T00:00:00.000Z",
  "updated_at": "2024-12-01T00:00:00.000Z"
}
```

**Error Response (422 - Invalid Mention):**
```json
{
  "error": "Looks like you tagged a user that doesn't exist: @fakeuser"
}
```

---

### PATCH /reviews/:id

Update a review (owner only).

**Authentication:** Required

**Request Body:**

```json
{
  "review": {
    "review_text": "Updated review text",
    "liked_aspects": ["melody"]
  }
}
```

**Response (200 OK):**
Returns updated review object

---

### DELETE /reviews/:id

Delete a review (owner only).

**Authentication:** Required

**Response (204 No Content)**

---

### GET /feed

Get review feed (same as GET /reviews).

**Authentication:** Required

**Response (200 OK):**
Returns array of reviews (same format as GET /reviews)

---

### GET /feed/following

Get paginated combined feed including:

- Your own reviews, posts, and events
- Reviews, posts, and events from users you follow
- Reviews about bands owned by users you follow

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "feed_items": [
    {
      "type": "review",
      "data": {
        "id": 1,
        "song_link": "https://open.spotify.com/track/...",
        "band_name": "Artist Name",
        "song_name": "Song Title",
        "artwork_url": "https://...",
        "review_text": "Great song!",
        "liked_aspects": ["melody", "lyrics"],
        "band": { ... },
        "author": {
          "id": 2,
          "username": "followeduser",
          "display_name": "Followed User",
          "profile_image_url": "https://..."
        },
        "likes_count": 3,
        "liked_by_current_user": true,
        "comments_count": 1,
        "created_at": "2024-12-01T00:00:00.000Z",
        "updated_at": "2024-12-01T00:00:00.000Z"
      }
    },
    {
      "type": "post",
      "data": {
        "id": 5,
        "title": "My Latest Album Review",
        "slug": "my-latest-album-review",
        "excerpt": "A deep dive into the new release...",
        "author": {
          "id": 3,
          "username": "musicblogger",
          "display_name": "Music Blogger",
          "profile_image_url": "https://..."
        },
        "created_at": "2024-12-01T00:00:00.000Z"
      }
    },
    {
      "type": "event",
      "data": {
        "id": 10,
        "title": "Live at the Roxy",
        "start_date": "2024-12-15T20:00:00.000Z",
        "venue": "The Roxy",
        "author": {
          "id": 4,
          "username": "bandaccount",
          "display_name": "Band Account",
          "profile_image_url": "https://..."
        },
        "created_at": "2024-12-01T00:00:00.000Z"
      }
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 45,
    "total_pages": 3,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

### GET /reviews/user

Get current user's most recent reviews (limit 5).

**Authentication:** Required

**Response (200 OK):**
Returns array of reviews (same format as GET /reviews)

---

### GET /users/:user_id/reviews

Get all reviews by a specific user.

**Authentication:** Required

**Response (200 OK):**
Returns array of reviews (same format as GET /reviews)

---

## Review Likes Endpoints

### POST /reviews/:id/like

Like a review.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Review liked successfully",
  "liked": true,
  "likes_count": 6
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have already liked this review"
}
```

---

### DELETE /reviews/:id/like

Unlike a review.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Review unliked successfully",
  "liked": false,
  "likes_count": 5
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have not liked this review"
}
```

---

### GET /reviews/liked

Get paginated list of reviews the current user has liked.

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "band_name": "Artist Name",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "band": { ... },
      "author": {
        "id": 2,
        "username": "anotheruser",
        "profile_image_url": "https://..."
      },
      "likes_count": 10,
      "liked_by_current_user": true,
      "comments_count": 4,
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 45,
    "total_pages": 3,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

## Review Comments Endpoints

### GET /reviews/:review_id/comments

Get paginated list of comments for a review.

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "comments": [
    {
      "id": 1,
      "body": "Great review! I totally agree.",
      "author": {
        "id": 2,
        "username": "musicfan",
        "display_name": "musicfan",
        "profile_image_url": "https://..."
      },
      "likes_count": 3,
      "liked_by_current_user": false,
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 5,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

---

### POST /reviews/:review_id/comments

Add a comment to a review.

**Authentication:** Required

**Request Body:**

```json
{
  "comment": {
    "body": "Great review! I totally agree."
  }
}
```

Note: Comment body is limited to 300 characters.

**Response (201 Created):**

```json
{
  "message": "Comment added successfully",
  "comment": {
    "id": 1,
    "body": "Great review! I totally agree.",
    "formatted_body": "Great review! I totally agree.",
    "mentions": [],
    "author": {
      "id": 2,
      "username": "musicfan",
      "display_name": "musicfan",
      "profile_image_url": "https://..."
    },
    "likes_count": 0,
    "liked_by_current_user": false,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  },
  "comments_count": 5
}
```

**Example with User Mention:**

Request:
```json
{
  "comment": {
    "body": "Hey @johndoe you should check this out!"
  }
}
```

Response:
```json
{
  "message": "Comment added successfully",
  "comment": {
    "id": 2,
    "body": "Hey @johndoe you should check this out!",
    "formatted_body": "Hey [@johndoe](user:123) you should check this out!",
    "mentions": [
      {
        "user_id": 123,
        "username": "johndoe",
        "display_name": "John Doe"
      }
    ],
    "author": {
      "id": 2,
      "username": "musicfan",
      "display_name": "musicfan",
      "profile_image_url": "https://..."
    },
    "likes_count": 0,
    "liked_by_current_user": false,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  },
  "comments_count": 6
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "errors": ["Body can't be blank"]
}
```

or

```json
{
  "errors": ["Body is too long (maximum is 300 characters)"]
}
```

or (invalid mention):

```json
{
  "error": "Looks like you tagged a user that doesn't exist: @fakeuser"
}
```

---

### PATCH /reviews/:review_id/comments/:id

Update a comment (owner only).

**Authentication:** Required

**Request Body:**

```json
{
  "comment": {
    "body": "Updated comment text."
  }
}
```

**Response (200 OK):**

```json
{
  "message": "Comment updated successfully",
  "comment": {
    "id": 1,
    "body": "Updated comment text.",
    "author": {
      "id": 2,
      "username": "musicfan",
      "display_name": "musicfan",
      "profile_image_url": "https://..."
    },
    "likes_count": 3,
    "liked_by_current_user": true,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "You are not authorized to modify this comment"
}
```

---

### DELETE /reviews/:review_id/comments/:id

Delete a comment (owner or admin only).

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Comment deleted successfully",
  "comments_count": 4
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "You are not authorized to modify this comment"
}
```

---

### POST /comments/:comment_id/like

Like a comment.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Comment liked successfully",
  "liked": true,
  "likes_count": 5
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have already liked this comment"
}
```

---

### DELETE /comments/:comment_id/like

Unlike a comment.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Comment unliked successfully",
  "liked": false,
  "likes_count": 4
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have not liked this comment"
}
```

---

## Blog/Posts Endpoints

Blog posts allow bands (starter+ plans) and bloggers to publish long-form content.

### GET /blogs/:username

Alias for `GET /users/:username`. Returns the full user profile with reviews and posts (for blogger users).

This endpoint exists so frontend routes like `/blog/:username` can call `/blogs/:username` on the backend with matching semantics.

**See:** [GET /users/:username](#get-usersusername) for full documentation.

**Authentication:** Optional (if authenticated, includes `following` field and `liked_by_current_user` for reviews)

**Query Parameters:**

- `page` (optional): Page number for reviews (default: 1)
- `per_page` (optional): Reviews per page (default: 20, max: 50)
- `posts_page` (optional): Page number for posts (default: 1)
- `posts_per_page` (optional): Posts per page (default: 10, max: 50)
- `tag` (optional): Filter posts by tag
- `category` (optional): Filter posts by category

---

### GET /blogs/:username/:slug

Get a single blog post by slug.

**Authentication:** Optional (owner can view drafts/scheduled posts)

**URL Parameters:**

- `username` (required): The username of the blog owner
- `slug` (required): The post slug

**Response (200 OK):**

```json
{
  "id": 1,
  "title": "My First Post",
  "slug": "my-first-post",
  "excerpt": "A brief introduction...",
  "body": "<p>Full HTML content from Tiptap editor...</p>",
  "featured": false,
  "status": "published",
  "publish_date": "2026-02-25T10:00:00Z",
  "featured_image_url": "https://...",
  "tags": ["music", "reviews"],
  "categories": ["tutorials"],
  "authors": [
    { "name": "John Doe", "url": null }
  ],
  "author": {
    "id": 123,
    "username": "johndoe",
    "display_name": "John Doe",
    "profile_image_url": "https://...",
    "allow_anonymous_comments": true
  },
  "song": {
    "song_name": "Bohemian Rhapsody",
    "band_name": "Queen",
    "album_name": "A Night at the Opera",
    "artwork_url": "https://...",
    "song_link": "https://song.link/...",
    "streaming_links": {
      "spotify": "https://open.spotify.com/track/...",
      "appleMusic": "https://music.apple.com/...",
      "youtubeMusic": "https://music.youtube.com/...",
      "tidal": "https://tidal.com/...",
      "amazonMusic": "https://music.amazon.com/...",
      "deezer": "https://deezer.com/...",
      "soundcloud": "https://soundcloud.com/...",
      "bandcamp": "https://....bandcamp.com/..."
    },
    "preferred_link": "https://open.spotify.com/track/...",
    "songlink_url": "https://song.link/...",
    "songlink_search_url": "https://www.google.com/search?q=Queen%20Bohemian%20Rhapsody%20spotify%20OR%20apple%20music",
    "band_links": {
      "spotify": "https://open.spotify.com/artist/...",
      "apple_music": "https://music.apple.com/artist/...",
      "youtube_music": "https://music.youtube.com/channel/...",
      "bandcamp": "https://queen.bandcamp.com",
      "soundcloud": null,
      "preferred_link": "https://open.spotify.com/artist/..."
    }
  },
  "likes_count": 42,
  "liked_by_current_user": false,
  "comments_count": 5,
  "can_edit": false,
  "created_at": "2026-02-25T09:00:00Z",
  "updated_at": "2026-02-25T10:00:00Z"
}
```

**Notes:**

- Non-published posts return 404 unless viewed by the owner
- `can_edit` is true only when the authenticated user is the post owner
- `song` is `null` if no song is attached to the post
- `song.streaming_links` contains platform-specific URLs fetched via Track enrichment
- `song.preferred_link` returns the streaming link matching the user's `preferred_streaming_platform` setting
- `song.songlink_search_url` is a fallback Google search URL when streaming links aren't available yet
- `song.band_links` contains the artist's streaming platform profile URLs
- `likes_count` shows the total number of likes on the post
- `liked_by_current_user` indicates whether the authenticated user has liked this post
- `comments_count` shows the total number of comments on the post

---

### GET /posts/:id

Get a post by ID (owner only). Used for editing posts.

**Authentication:** Required (owner only)

**URL Parameters:**

- `id` (required): The post ID

**Response (200 OK):**

Returns the full post object (same as GET /blogs/:username/:slug).

**Response (401 Unauthorized):**

```json
{
  "error": "You can only modify resources you own"
}
```

**Notes:**

- Only the post owner can access this endpoint
- Returns full post data including body for editing
- Use this endpoint when you have the post ID (e.g., from the management list)

---

### POST /posts

Create a new blog post.

**Authentication:** Required

**Required Ability:** `create_blog_post`

**Request Body:**

```json
{
  "post": {
    "title": "My New Post",
    "slug": "my-new-post",
    "excerpt": "Optional excerpt for previews",
    "body": "<p>HTML content</p>",
    "status": "draft",
    "featured": false,
    "publish_date": "2026-03-01T12:00:00Z",
    "tags": ["music", "news"],
    "categories": ["announcements"],
    "authors": [
      { "name": "Guest Author", "url": "https://guest.com" }
    ],
    "song_name": "Bohemian Rhapsody",
    "band_name": "Queen",
    "album_name": "A Night at the Opera",
    "artwork_url": "https://example.com/artwork.jpg",
    "song_link": "https://song.link/example"
  }
}
```

**Response (201 Created):**

Returns the full post object (same as GET /blogs/:username/:slug).

**Field Notes:**

| Field | Required | Notes |
|-------|----------|-------|
| `title` | Yes | Post title |
| `slug` | No | Auto-generated from title if not provided |
| `body` | Yes (if published) | HTML content from Tiptap |
| `status` | No | `draft` (default), `published`, or `scheduled` |
| `featured` | No | Default false |
| `publish_date` | Yes (if scheduled) | Must be in the future for scheduled posts |
| `tags` | No | Array of strings |
| `categories` | No | Array of strings |
| `authors` | No | Array of {name, url} objects; defaults to owner |
| `featured_image` | No | File upload for featured image |
| `song_name` | No | Name of the attached song |
| `band_name` | No | Artist/band name for the song |
| `album_name` | No | Album name (optional) |
| `artwork_url` | No | URL to album/song artwork (also accepts `song_artwork_url`) |
| `song_link` | No | Generic song link (e.g., song.link URL) |

**Song Attachment Notes:**

- When `song_name` and `band_name` are provided, the system automatically finds or creates a Track record
- Streaming links (Spotify, Apple Music, etc.) are enriched asynchronously via background jobs
- Use `GET /api/v1/scrobbles/recent` to fetch recently played songs for a song picker UI
- Use `GET /api/v1/search` to search for songs by name

**Required Abilities by Feature:**

| Feature | Required Ability |
|---------|------------------|
| Create post | `create_blog_post` |
| Save as draft | `draft_posts` |
| Schedule post | `schedule_post` |
| Attach featured image | `attach_images` |
| Add tags/categories | `manage_tags` |

**Response (403 Forbidden) - Upgrade Required:**

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "create_blog_post",
  "upgrade_plan": "band_starter"
}
```

---

### PATCH /posts/:id

Update an existing post.

**Authentication:** Required (owner only)

**URL Parameters:**

- `id` (required): The post ID

**Request Body:**

Same fields as POST /posts (all optional).

**Response (200 OK):**

Returns the updated full post object.

**Notes:**

- Only the post owner can update
- Same ability checks as create for specific features
- Song attachment can be added, updated, or removed (set fields to `null` to remove)

---

### DELETE /posts/:id

Delete a post.

**Authentication:** Required (owner only)

**URL Parameters:**

- `id` (required): The post ID

**Response (204 No Content):**

Empty response body.

---

### GET /posts/my

Get the current user's posts for management (all statuses including drafts). Paginated with a lightweight response format.

**Authentication:** Required

**Query Parameters:**

- `status` (optional): Filter by status (`draft`, `published`, `scheduled`)
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "posts": [
    {
      "id": 1,
      "title": "My Draft Post",
      "slug": "my-draft-post",
      "status": "draft",
      "featured": false,
      "authors": [{ "name": "johndoe", "url": null }],
      "publish_date": null,
      "created_at": "2026-02-25T09:00:00Z",
      "updated_at": "2026-02-25T09:00:00Z"
    },
    {
      "id": 2,
      "title": "Published Article",
      "slug": "published-article",
      "status": "published",
      "featured": true,
      "authors": [{ "name": "johndoe", "url": null }],
      "publish_date": "2026-02-24T10:00:00Z",
      "created_at": "2026-02-24T08:00:00Z",
      "updated_at": "2026-02-24T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 45,
    "total_pages": 3,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

**Notes:**

- Returns all posts for the current user, including drafts and scheduled
- Ordered by creation date (newest first)
- Lightweight response format optimized for management lists (no body, excerpt, tags, categories, or images)
- Use GET /blogs/:username/:slug to fetch full post details for editing

---

### POST /blog_images

Upload an image for use in blog post content.

**Authentication:** Required

**Required Ability:** `attach_images`

**Content-Type:** `multipart/form-data`

**Request Body:**

- `image` (required): Image file (JPEG, PNG, WebP, or GIF)

**Constraints:**

- Maximum file size: 5MB
- Allowed formats: JPEG, PNG, WebP, GIF

**Response (201 Created):**

```json
{
  "id": 123,
  "url": "https://api.goodsongs.app/rails/active_storage/blobs/.../image.jpg",
  "filename": "my-image.jpg",
  "content_type": "image/jpeg",
  "byte_size": 245000
}
```

**Response (422 Unprocessable Entity) - Invalid file type:**

```json
{
  "error": "Invalid file type. Allowed: JPEG, PNG, WebP, GIF"
}
```

**Response (422 Unprocessable Entity) - File too large:**

```json
{
  "error": "File too large. Maximum size: 5MB"
}
```

**Response (403 Forbidden) - Upgrade required:**

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "attach_images",
  "upgrade_plan": "band_starter"
}
```

**Notes:**

- Use the returned `url` in your Tiptap editor to embed the image in post content
- Images are stored permanently and associated with the uploading user
- The URL can be used directly in `<img>` tags within the post body HTML

---

### Plan Access Matrix for Blog Posts

| Plan | Create Posts | Draft | Schedule | Attach Images | Manage Tags |
|------|-------------|-------|----------|---------------|-------------|
| fan_free | No | No | No | No | No |
| band_free | No | No | No | No | No |
| band_starter | **Yes** | **Yes** | No | **Yes** | **Yes** |
| band_pro | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** |
| blogger | **Yes** | **Yes** | No | **Yes** | **Yes** |
| blogger_pro | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** |

---

## Post Likes Endpoints

### POST /posts/:id/like

Like a blog post.

**Authentication:** Required

**URL Parameters:**

- `id` (required): The post ID

**Response (200 OK):**

```json
{
  "message": "Post liked successfully",
  "liked": true,
  "likes_count": 43
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have already liked this post"
}
```

---

### DELETE /posts/:id/like

Unlike a blog post.

**Authentication:** Required

**URL Parameters:**

- `id` (required): The post ID

**Response (200 OK):**

```json
{
  "message": "Post unliked successfully",
  "liked": false,
  "likes_count": 42
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have not liked this post"
}
```

---

### GET /posts/liked

Get paginated list of blog posts the current user has liked.

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "posts": [
    {
      "id": 1,
      "title": "My First Post",
      "slug": "my-first-post",
      "excerpt": "A brief introduction...",
      "featured": false,
      "status": "published",
      "publish_date": "2026-02-25T10:00:00Z",
      "featured_image_url": "https://...",
      "tags": ["music", "reviews"],
      "categories": ["tutorials"],
      "authors": [
        { "name": "John Doe", "url": null }
      ],
      "author": {
        "id": 123,
        "username": "johndoe",
        "display_name": "John Doe",
        "profile_image_url": "https://...",
        "allow_anonymous_comments": true
      },
      "song": null,
      "likes_count": 42,
      "liked_by_current_user": true,
      "comments_count": 5,
      "created_at": "2026-02-25T09:00:00Z",
      "updated_at": "2026-02-25T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 15,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

---

## Post Comments Endpoints

Post comments support both authenticated and anonymous commenting. Anonymous comments require the post author to have `allow_anonymous_comments: true` in their profile settings.

### GET /posts/:post_id/comments

Get paginated list of comments for a post.

**Authentication:** Optional (affects `liked_by_current_user` field)

**URL Parameters:**

- `post_id` (required): The post ID

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "comments": [
    {
      "id": 1,
      "body": "Great post!",
      "formatted_body": "Great post!",
      "mentions": [],
      "anonymous": false,
      "author": {
        "id": 123,
        "username": "johndoe",
        "display_name": "John Doe",
        "profile_image_url": "https://..."
      },
      "likes_count": 5,
      "liked_by_current_user": false,
      "created_at": "2026-02-26T10:00:00Z",
      "updated_at": "2026-02-26T10:00:00Z"
    },
    {
      "id": 2,
      "body": "Thanks for sharing!",
      "anonymous": true,
      "guest_name": "Anonymous Reader",
      "likes_count": 2,
      "liked_by_current_user": false,
      "created_at": "2026-02-26T11:00:00Z",
      "updated_at": "2026-02-26T11:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 2,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

**Notes:**

- Anonymous comments show `guest_name` but never expose `guest_email`
- Anonymous comments don't have `formatted_body`, `mentions`, or `author` fields
- Authenticated comments support @mentions with `formatted_body` containing clickable links

---

### POST /posts/:post_id/comments

Create a new comment on a post. Supports both authenticated and anonymous comments.

**Authentication:** Optional (anonymous requires post author's `allow_anonymous_comments: true`)

**URL Parameters:**

- `post_id` (required): The post ID

**Request Body (Authenticated):**

```json
{
  "comment": {
    "body": "Great post! @johndoe what do you think?"
  }
}
```

**Request Body (Anonymous):**

```json
{
  "comment": {
    "body": "Thanks for sharing!",
    "guest_name": "Anonymous Reader",
    "guest_email": "reader@example.com"
  }
}
```

**Response (201 Created) - Authenticated:**

```json
{
  "message": "Comment added successfully",
  "comment": {
    "id": 1,
    "body": "Great post! @johndoe what do you think?",
    "formatted_body": "Great post! <a href=\"/users/johndoe\">@johndoe</a> what do you think?",
    "mentions": [
      {
        "user_id": 123,
        "username": "johndoe",
        "display_name": "John Doe"
      }
    ],
    "anonymous": false,
    "author": {
      "id": 456,
      "username": "commenter",
      "display_name": "Commenter Name",
      "profile_image_url": "https://..."
    },
    "likes_count": 0,
    "liked_by_current_user": false,
    "created_at": "2026-02-26T10:00:00Z",
    "updated_at": "2026-02-26T10:00:00Z"
  },
  "comments_count": 5
}
```

**Response (201 Created) - Anonymous:**

```json
{
  "message": "Comment added successfully",
  "comment": {
    "id": 2,
    "body": "Thanks for sharing!",
    "anonymous": true,
    "guest_name": "Anonymous Reader",
    "likes_count": 0,
    "liked_by_current_user": false,
    "created_at": "2026-02-26T11:00:00Z",
    "updated_at": "2026-02-26T11:00:00Z"
  },
  "claim_token": "abc123xyz...",
  "comments_count": 6
}
```

**Error Response (403 Forbidden) - Anonymous not allowed:**

```json
{
  "error": "Anonymous comments are not allowed on this post"
}
```

**Notes:**

- Anonymous comments return a `claim_token` that can be used to link the comment to a user account after signup
- Anonymous comments do not support @mentions
- Store the `claim_token` in localStorage and call `/post_comments/claim` after user signup

---

### PATCH /posts/:post_id/comments/:id

Update an existing comment (owner only).

**Authentication:** Required

**URL Parameters:**

- `post_id` (required): The post ID
- `id` (required): The comment ID

**Request Body:**

```json
{
  "comment": {
    "body": "Updated comment text"
  }
}
```

**Response (200 OK):**

```json
{
  "message": "Comment updated successfully",
  "comment": {
    "id": 1,
    "body": "Updated comment text",
    "formatted_body": "Updated comment text",
    "mentions": [],
    "anonymous": false,
    "author": {
      "id": 456,
      "username": "commenter",
      "display_name": "Commenter Name",
      "profile_image_url": "https://..."
    },
    "likes_count": 5,
    "liked_by_current_user": false,
    "created_at": "2026-02-26T10:00:00Z",
    "updated_at": "2026-02-26T12:00:00Z"
  }
}
```

**Error Response (403 Forbidden) - Not owner:**

```json
{
  "error": "You are not authorized to modify this comment"
}
```

**Error Response (403 Forbidden) - Anonymous comment:**

```json
{
  "error": "Anonymous comments cannot be edited"
}
```

**Notes:**

- Only the comment owner or admin can update comments
- Anonymous comments cannot be edited (they must be claimed first)

---

### DELETE /posts/:post_id/comments/:id

Delete a comment (owner or admin only).

**Authentication:** Required

**URL Parameters:**

- `post_id` (required): The post ID
- `id` (required): The comment ID

**Response (200 OK):**

```json
{
  "message": "Comment deleted successfully",
  "comments_count": 4
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "You are not authorized to modify this comment"
}
```

**Notes:**

- Comment owner or admin can delete comments
- For anonymous comments, only admin can delete

---

### POST /post_comments/claim

Claim an anonymous comment by linking it to the authenticated user's account.

**Authentication:** Required

**Request Body:**

```json
{
  "claim_token": "abc123xyz..."
}
```

**Response (200 OK):**

```json
{
  "message": "Comment claimed successfully",
  "comment": {
    "id": 2,
    "body": "Thanks for sharing!",
    "formatted_body": "Thanks for sharing!",
    "mentions": [],
    "anonymous": false,
    "author": {
      "id": 789,
      "username": "newuser",
      "display_name": "New User",
      "profile_image_url": "https://..."
    },
    "likes_count": 2,
    "liked_by_current_user": false,
    "created_at": "2026-02-26T11:00:00Z",
    "updated_at": "2026-02-26T14:00:00Z"
  }
}
```

**Error Response (400 Bad Request):**

```json
{
  "error": "Claim token is required"
}
```

**Error Response (404 Not Found):**

```json
{
  "error": "Invalid or expired claim token"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "Comment has already been claimed"
}
```

**Notes:**

- Claim tokens are single-use and cleared after claiming
- After claiming, the comment becomes a regular authenticated comment
- The `guest_name` and `guest_email` fields are cleared upon claiming

---

### POST /post_comments/:comment_id/like

Like a post comment.

**Authentication:** Required

**URL Parameters:**

- `comment_id` (required): The comment ID

**Response (200 OK):**

```json
{
  "message": "Comment liked successfully",
  "liked": true,
  "likes_count": 6
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have already liked this comment"
}
```

---

### DELETE /post_comments/:comment_id/like

Unlike a post comment.

**Authentication:** Required

**URL Parameters:**

- `comment_id` (required): The comment ID

**Response (200 OK):**

```json
{
  "message": "Comment unliked successfully",
  "liked": false,
  "likes_count": 5
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have not liked this comment"
}
```

---

### Anonymous Comments Flow

1. **Guest posts comment** with `guest_name` and `guest_email` (if `allow_anonymous_comments` is enabled)
2. **Server returns `claim_token`** in the response
3. **Frontend stores `claim_token`** in localStorage
4. **Frontend shows "Create account?" prompt** to encourage signup
5. **After signup**, frontend calls `POST /post_comments/claim` with the stored token
6. **Comment is linked** to the new user account, guest fields cleared

---

## Band Endpoints

### GET /bands

Get all bands (ordered by name).

**Authentication:** None

**Response (200 OK):**

```json
[
  {
    "id": 1,
    "slug": "band-name",
    "name": "Band Name",
    "city": "New York",
    "region": "New York",
    "location": "New York, New York",
    "latitude": 40.7128,
    "longitude": -74.006,
    "spotify_link": "https://open.spotify.com/artist/...",
    "bandcamp_link": "https://bandname.bandcamp.com",
    "apple_music_link": null,
    "youtube_music_link": null,
    "musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
    "lastfm_artist_name": "Band Name",
    "lastfm_url": "https://www.last.fm/music/Band+Name",
    "about": "We make great music",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "user_owned": true,
    "owner": { "id": 1, "username": "johndoe" },
    "social_links": {
      "instagram": "https://instagram.com/bandname",
      "twitter": "https://twitter.com/bandname",
      "tiktok": "https://tiktok.com/@bandname"
    },
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
]
```

---

### GET /bands/:slug

Get a single band by slug (includes reviews).

**Authentication:** None

**Response (200 OK):**

```json
{
  "id": 1,
  "slug": "band-name",
  "name": "Band Name",
  "city": "New York",
  "region": "New York",
  "location": "New York, New York",
  "latitude": 40.7128,
  "longitude": -74.006,
  "spotify_link": "https://open.spotify.com/artist/...",
  "bandcamp_link": "https://bandname.bandcamp.com",
  "apple_music_link": null,
  "youtube_music_link": null,
  "musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
  "lastfm_artist_name": "Band Name",
  "lastfm_url": "https://www.last.fm/music/Band+Name",
  "about": "We make great music",
  "profile_picture_url": "https://...",
  "reviews_count": 5,
  "user_owned": true,
  "owner": { "id": 1, "username": "johndoe" },
  "created_at": "2024-12-01T00:00:00.000Z",
  "updated_at": "2024-12-01T00:00:00.000Z",
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "author": {
        "id": 2,
        "username": "reviewer",
        "profile_image_url": "https://..."
      },
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ]
}
```

---

### POST /bands

Create a new band.

**Authentication:** Required

**Request Body (multipart/form-data):**

```
band[name]: "Band Name" (required)
band[city]: "New York"
band[region]: "New York"
band[spotify_link]: "https://open.spotify.com/artist/..."
band[bandcamp_link]: "https://bandname.bandcamp.com"
band[apple_music_link]: "https://music.apple.com/..."
band[youtube_music_link]: "https://music.youtube.com/..."
band[about]: "We make great music"
band[profile_picture]: <file>
band[instagram_url]: "https://instagram.com/bandname"
band[threads_url]: "https://threads.net/@bandname"
band[bluesky_url]: "https://bsky.app/profile/bandname.bsky.social"
band[twitter_url]: "https://twitter.com/bandname"
band[tumblr_url]: "https://bandname.tumblr.com"
band[tiktok_url]: "https://tiktok.com/@bandname"
band[facebook_url]: "https://facebook.com/bandname"
band[youtube_url]: "https://youtube.com/@bandname"
```

**Social Links (all optional):**
- `instagram_url`: Instagram profile URL
- `threads_url`: Threads profile URL
- `bluesky_url`: Bluesky profile URL
- `twitter_url`: Twitter/X profile URL
- `tumblr_url`: Tumblr blog URL
- `tiktok_url`: TikTok profile URL
- `facebook_url`: Facebook page URL
- `youtube_url`: YouTube channel URL

Note: When city/region are provided, latitude and longitude are automatically calculated via geocoding.

**Response (201 Created):**
Returns created band object

---

### PATCH /bands/:slug

Update a band (owner only).

**Authentication:** Required

**Request Body (multipart/form-data):**
Same fields as POST /bands

**Response (200 OK):**
Returns updated band object

---

### DELETE /bands/:slug

Delete a band (owner only).

**Authentication:** Required

**Response (204 No Content)**

---

### GET /bands/user

Get all bands owned by the current user.

**Authentication:** Required

**Response (200 OK):**
Returns array of bands (same format as GET /bands)

---

## Event Endpoints

Events can be created either as standalone events (by any user with `manage_events` ability) or nested under a band. The `band` field is `null` for events not associated with a band.

### Event Object

```json
{
  "id": 1,
  "name": "Summer Tour Kickoff",
  "description": "Join us for the first show of our summer tour!",
  "event_date": "2025-07-15T20:00:00.000Z",
  "ticket_link": "https://tickets.example.com/event/123",
  "image_url": "https://...",
  "price": "$25",
  "age_restriction": "21+",
  "venue": {
    "id": 1,
    "name": "The Roxy",
    "address": "9009 Sunset Blvd",
    "city": "West Hollywood",
    "region": "California",
    "latitude": 34.0901,
    "longitude": -118.3868
  },
  "band": {
    "id": 1,
    "slug": "band-name",
    "name": "Band Name",
    "location": "Los Angeles, California",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "user_owned": true
  },
  "user_id": 1,
  "likes_count": 12,
  "liked_by_current_user": false,
  "comments_count": 3,
  "created_at": "2025-01-01T00:00:00.000Z",
  "updated_at": "2025-01-01T00:00:00.000Z"
}
```

**Notes:**
- `band` is `null` when the event is not associated with a band
- `user_id` is always present and identifies the event creator
- `likes_count`, `liked_by_current_user`, and `comments_count` are included in event responses

---

### GET /events

Get all upcoming visible events (both band and non-band events).

**Authentication:** None

**Response (200 OK):**

```json
[
  {
    "id": 1,
    "name": "Summer Tour Kickoff",
    "band": { "...": "..." },
    "user_id": 1,
    "...": "..."
  },
  {
    "id": 2,
    "name": "Open Mic Night",
    "band": null,
    "user_id": 5,
    "...": "..."
  }
]
```

**Notes:**
- Returns active, upcoming events sorted by `event_date` ascending
- Includes events with no band and events with an active (non-disabled) band
- Events belonging to disabled bands are excluded

---

### GET /bands/:slug/events

Get upcoming events for a specific band.

**Authentication:** None

**Response (200 OK):**
Returns array of event objects for the band (same format as Event Object above)

---

### POST /events

Create a standalone event (not tied to a band).

**Authentication:** Required

**Required Ability:** `manage_events`

**Request Body:**

```json
{
  "event": {
    "name": "Open Mic Night",
    "description": "Weekly open mic at The Roxy!",
    "event_date": "2025-07-15T20:00:00.000Z",
    "ticket_link": "https://tickets.example.com/event/456",
    "price": "Free",
    "age_restriction": "All Ages",
    "venue_id": 1,
    "band_id": 1
  }
}
```

Or with new venue:

```json
{
  "event": {
    "name": "Open Mic Night",
    "description": "Weekly open mic at The Roxy!",
    "event_date": "2025-07-15T20:00:00.000Z",
    "venue_attributes": {
      "name": "The Roxy",
      "address": "9009 Sunset Blvd",
      "city": "West Hollywood",
      "region": "California"
    }
  }
}
```

**Fields:**

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Event name |
| `event_date` | Yes | ISO 8601 datetime |
| `venue_id` | Yes* | Existing venue ID (*one of `venue_id` or `venue_attributes` required) |
| `venue_attributes` | Yes* | `{name, address, city, region}` for new venue |
| `description` | No | Event description |
| `ticket_link` | No | URL to purchase tickets |
| `price` | No | Price display string (e.g., "$25", "Free") |
| `age_restriction` | No | `"All Ages"`, `"18+"`, or `"21+"` |
| `image` | No | Event image file (multipart/form-data) |
| `image_url` | No | Event image URL |
| `band_id` | No | Associate with a band you own (validated) |

**Response (201 Created):**
Returns created event object

**Error Response (422 Unprocessable Entity) - Band not owned:**

```json
{
  "errors": ["Band not found or not owned by you"]
}
```

**Error Response (403 Forbidden) - Upgrade required:**

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "manage_events",
  "upgrade_plan": "band_starter"
}
```

**Notes:**
- The event is always owned by the authenticated user (`user_id` is set automatically)
- `band_id` is optional; if provided, the band must be owned by the current user
- Any user with the `manage_events` ability can create events (not just band accounts)

---

### POST /bands/:slug/events

Create a new event for a specific band.

**Authentication:** Required (band owner + `manage_events` ability)

**Request Body:**

```json
{
  "event": {
    "name": "Summer Tour Kickoff",
    "description": "Join us for the first show!",
    "event_date": "2025-07-15T20:00:00.000Z",
    "ticket_link": "https://tickets.example.com/event/123",
    "price": "$25",
    "age_restriction": "21+",
    "venue_id": 1
  }
}
```

Or with new venue:

```json
{
  "event": {
    "name": "Summer Tour Kickoff",
    "description": "Join us for the first show!",
    "event_date": "2025-07-15T20:00:00.000Z",
    "venue_attributes": {
      "name": "The Roxy",
      "address": "9009 Sunset Blvd",
      "city": "West Hollywood",
      "region": "California"
    }
  }
}
```

For image upload, use multipart/form-data:

```
event[name]: "Summer Tour Kickoff"
event[event_date]: "2025-07-15T20:00:00.000Z"
event[venue_id]: 1
event[image]: <file>
```

**Response (201 Created):**
Returns created event object

**Notes:**
- You must own the band specified by `:slug`
- The event's `user_id` is automatically set to the authenticated user
- The event's `band_id` is automatically set to the band

---

### GET /events/:id

Get a single event by ID.

**Authentication:** None

**Response (200 OK):**
Returns event object (same format as Event Object above, including `likes_count`, `liked_by_current_user`, and `comments_count`)

---

### PATCH /events/:id

Update an event.

**Authentication:** Required (event creator only)

**Request Body:**

```json
{
  "event": {
    "name": "Updated Event Name",
    "description": "Updated description",
    "event_date": "2025-07-20T21:00:00.000Z"
  }
}
```

**Response (200 OK):**
Returns updated event object

**Error Response (403 Forbidden):**

```json
{
  "error": "You can only modify your own events"
}
```

---

### DELETE /events/:id

Delete an event.

**Authentication:** Required (event creator only)

**Response (204 No Content)**

**Error Response (403 Forbidden):**

```json
{
  "error": "You can only modify your own events"
}
```

---

### GET /users/:user_id/events

Get upcoming events created by a specific user.

**Authentication:** None

**URL Parameters:**

- `user_id` (required): The user's ID

**Response (200 OK):**

```json
[
  {
    "id": 1,
    "name": "Summer Tour Kickoff",
    "band": { "...": "..." },
    "user_id": 1,
    "...": "..."
  },
  {
    "id": 2,
    "name": "Open Mic Night",
    "band": null,
    "user_id": 1,
    "...": "..."
  }
]
```

**Notes:**
- Returns active, upcoming events sorted by `event_date` ascending
- Includes both band and non-band events created by the user

---

## Event Likes Endpoints

### POST /events/:id/like

Like an event.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Event liked successfully",
  "liked": true,
  "likes_count": 13
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have already liked this event"
}
```

---

### DELETE /events/:id/like

Unlike an event.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Event unliked successfully",
  "liked": false,
  "likes_count": 12
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have not liked this event"
}
```

---

### GET /events/liked

Get paginated list of events the current user has liked.

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "events": [
    {
      "id": 1,
      "name": "Summer Tour Kickoff",
      "description": "Join us for the first show of our summer tour!",
      "event_date": "2025-07-15T20:00:00.000Z",
      "ticket_link": "https://tickets.example.com/event/123",
      "image_url": "https://...",
      "price": "$25",
      "age_restriction": "21+",
      "venue": {
        "id": 1,
        "name": "The Roxy",
        "address": "9009 Sunset Blvd",
        "city": "West Hollywood",
        "region": "California",
        "latitude": 34.0901,
        "longitude": -118.3868
      },
      "band": {
        "id": 1,
        "slug": "band-name",
        "name": "Band Name",
        "location": "Los Angeles, California",
        "profile_picture_url": "https://...",
        "reviews_count": 5,
        "user_owned": true
      },
      "user_id": 1,
      "likes_count": 12,
      "liked_by_current_user": true,
      "comments_count": 3,
      "created_at": "2025-01-01T00:00:00.000Z",
      "updated_at": "2025-01-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 8,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

---

## Event Comments Endpoints

### GET /events/:event_id/comments

Get paginated list of comments for an event.

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "comments": [
    {
      "id": 1,
      "body": "Can't wait for this show!",
      "formatted_body": "Can't wait for this show!",
      "mentions": [],
      "author": {
        "id": 2,
        "username": "musicfan",
        "display_name": "musicfan",
        "profile_image_url": "https://..."
      },
      "likes_count": 3,
      "liked_by_current_user": false,
      "created_at": "2025-01-01T00:00:00.000Z",
      "updated_at": "2025-01-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 5,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

---

### POST /events/:event_id/comments

Add a comment to an event.

**Authentication:** Required

**Request Body:**

```json
{
  "comment": {
    "body": "Can't wait for this show!"
  }
}
```

Note: Comment body is limited to 300 characters.

**Response (201 Created):**

```json
{
  "message": "Comment added successfully",
  "comment": {
    "id": 1,
    "body": "Can't wait for this show!",
    "formatted_body": "Can't wait for this show!",
    "mentions": [],
    "author": {
      "id": 2,
      "username": "musicfan",
      "display_name": "musicfan",
      "profile_image_url": "https://..."
    },
    "likes_count": 0,
    "liked_by_current_user": false,
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  },
  "comments_count": 5
}
```

**Example with User Mention:**

Request:
```json
{
  "comment": {
    "body": "Hey @johndoe you should come to this!"
  }
}
```

Response:
```json
{
  "message": "Comment added successfully",
  "comment": {
    "id": 2,
    "body": "Hey @johndoe you should come to this!",
    "formatted_body": "Hey [@johndoe](user:123) you should come to this!",
    "mentions": [
      {
        "user_id": 123,
        "username": "johndoe",
        "display_name": "John Doe"
      }
    ],
    "author": {
      "id": 2,
      "username": "musicfan",
      "display_name": "musicfan",
      "profile_image_url": "https://..."
    },
    "likes_count": 0,
    "liked_by_current_user": false,
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  },
  "comments_count": 6
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "errors": ["Body can't be blank"]
}
```

or

```json
{
  "errors": ["Body is too long (maximum is 300 characters)"]
}
```

or (invalid mention):

```json
{
  "error": "Looks like you tagged a user that doesn't exist: @fakeuser"
}
```

---

### PATCH /events/:event_id/comments/:id

Update a comment (owner or admin only).

**Authentication:** Required

**Request Body:**

```json
{
  "comment": {
    "body": "Updated comment text."
  }
}
```

**Response (200 OK):**

```json
{
  "message": "Comment updated successfully",
  "comment": {
    "id": 1,
    "body": "Updated comment text.",
    "author": {
      "id": 2,
      "username": "musicfan",
      "display_name": "musicfan",
      "profile_image_url": "https://..."
    },
    "likes_count": 3,
    "liked_by_current_user": true,
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "You are not authorized to modify this comment"
}
```

---

### DELETE /events/:event_id/comments/:id

Delete a comment (owner or admin only).

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Comment deleted successfully",
  "comments_count": 4
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "You are not authorized to modify this comment"
}
```

---

### POST /event_comments/:comment_id/like

Like an event comment.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Comment liked successfully",
  "liked": true,
  "likes_count": 5
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have already liked this comment"
}
```

---

### DELETE /event_comments/:comment_id/like

Unlike an event comment.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Comment unliked successfully",
  "liked": false,
  "likes_count": 4
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You have not liked this comment"
}
```

---

## Venue Endpoints

### GET /venues

Get all venues. Supports search by name.

**Authentication:** None

**Query Parameters:**

- `search` (optional): Search venues by name

**Response (200 OK):**

```json
[
  {
    "id": 1,
    "name": "The Roxy",
    "address": "9009 Sunset Blvd",
    "city": "West Hollywood",
    "region": "California",
    "latitude": 34.0901,
    "longitude": -118.3868,
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
]
```

---

### GET /venues/:id

Get a single venue by ID.

**Authentication:** None

**Response (200 OK):**
Returns venue object (same format as GET /venues items)

---

### POST /venues

Create a new venue.

**Authentication:** Required

**Request Body:**

```json
{
  "venue": {
    "name": "The Roxy",
    "address": "9009 Sunset Blvd",
    "city": "West Hollywood",
    "region": "California"
  }
}
```

Note: Latitude and longitude are automatically calculated via geocoding.

**Response (201 Created):**
Returns created venue object

---

## Notification Endpoints

### GET /notifications

Get paginated list of notifications for the current user.

**Authentication:** Required

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "notifications": [
    {
      "id": 1,
      "type": "new_follower",
      "read": false,
      "created_at": "2024-12-04T00:00:00.000Z",
      "actor": {
        "id": 2,
        "username": "janedoe",
        "display_name": "janedoe",
        "profile_image_url": "https://..."
      },
      "message": "janedoe started following you"
    },
    {
      "id": 2,
      "type": "new_review",
      "read": true,
      "created_at": "2024-12-03T00:00:00.000Z",
      "actor": {
        "id": 3,
        "username": "musicfan",
        "display_name": "musicfan",
        "profile_image_url": "https://..."
      },
      "message": "musicfan reviewed Your Song Title",
      "review": {
        "id": 5,
        "song_name": "Your Song Title",
        "band_name": "Your Band"
      }
    },
    {
      "id": 3,
      "type": "review_like",
      "read": false,
      "created_at": "2024-12-02T00:00:00.000Z",
      "actor": {
        "id": 4,
        "username": "listener",
        "display_name": "listener",
        "profile_image_url": "https://..."
      },
      "message": "listener liked your review of Song Title",
      "review": {
        "id": 10,
        "song_name": "Song Title",
        "band_name": "Band Name"
      }
    },
    {
      "id": 4,
      "type": "review_comment",
      "read": false,
      "created_at": "2024-12-01T00:00:00.000Z",
      "actor": {
        "id": 5,
        "username": "commenter",
        "display_name": "commenter",
        "profile_image_url": "https://..."
      },
      "message": "commenter commented on your review of Song Title",
      "review": {
        "id": 10,
        "song_name": "Song Title",
        "band_name": "Band Name"
      },
      "comment": {
        "id": 1,
        "body": "Great review! I totally agree with your take..."
      }
    }
  ],
  "unread_count": 3,
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 15,
    "total_pages": 1,
    "has_next_page": false,
    "has_previous_page": false
  }
}
```

---

### GET /notifications/unread_count

Get count of unread notifications.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "unread_count": 5
}
```

---

### PATCH /notifications/:id/read

Mark a specific notification as read.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Notification marked as read",
  "notification": {
    "id": 1,
    "type": "new_follower",
    "read": true,
    "created_at": "2024-12-04T00:00:00.000Z",
    "actor": { ... },
    "message": "janedoe started following you"
  }
}
```

---

### PATCH /notifications/read_all

Mark all notifications as read.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "All notifications marked as read"
}
```

---

## Device Token Endpoints (Push Notifications)

These endpoints manage device tokens for Firebase Cloud Messaging (FCM) push notifications.

### POST /device_tokens

Register a device token for push notifications. Call this after the user logs in and grants notification permissions.

**Authentication:** Required

**Request Body:**

```json
{
  "device_token": {
    "token": "fcm_device_token_here",
    "platform": "android"
  }
}
```

**Fields:**

- `token` (required): The FCM device token from the mobile app
- `platform` (required): Either "ios" or "android"

**Response (200 OK):**

```json
{
  "message": "Device registered successfully"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "Token can't be blank, Platform is not included in the list"
}
```

**Notes:**

- If the token already exists for this user, it will be updated (platform and last_used_at)
- If the token exists for a different user, it will be moved to the current user
- Tokens are automatically cleaned up when FCM reports them as invalid

---

### DELETE /device_tokens

Unregister a device token (e.g., when user logs out or disables notifications).

**Authentication:** Required

**Request Body:**

```json
{
  "token": "fcm_device_token_here"
}
```

**Response (200 OK):**

```json
{
  "message": "Device unregistered successfully"
}
```

**Notes:**

- Returns success even if the token doesn't exist (idempotent)
- Call this when the user logs out to stop receiving notifications on that device

---

## Push Notification Types

When in-app notifications are created, push notifications are automatically sent to all registered devices. The push notification payload includes:

**new_follower:**
```json
{
  "title": "New Follower",
  "body": "username started following you",
  "data": {
    "type": "new_follower",
    "notification_id": "123",
    "actor_id": "456"
  }
}
```

**new_review:**
```json
{
  "title": "New Review",
  "body": "username reviewed Song Name",
  "data": {
    "type": "new_review",
    "notification_id": "123",
    "review_id": "789"
  }
}
```

**review_like:**
```json
{
  "title": "New Like",
  "body": "username liked your review of Song Name",
  "data": {
    "type": "review_like",
    "notification_id": "123",
    "review_id": "789"
  }
}
```

**review_comment:**
```json
{
  "title": "New Comment",
  "body": "username: \"Comment preview...\"",
  "data": {
    "type": "review_comment",
    "notification_id": "123",
    "review_id": "789",
    "comment_id": "101"
  }
}
```

**event_like:**
```json
{
  "title": "New Like",
  "body": "username liked your event Event Name",
  "data": {
    "type": "event_like",
    "notification_id": "123",
    "event_id": "789"
  }
}
```

**event_comment:**
```json
{
  "title": "New Comment",
  "body": "username: \"Comment preview...\"",
  "data": {
    "type": "event_comment",
    "notification_id": "123",
    "event_id": "789",
    "comment_id": "101"
  }
}
```

**event_comment_like:**
```json
{
  "title": "New Like",
  "body": "username liked your comment on Event Name",
  "data": {
    "type": "event_comment_like",
    "notification_id": "123",
    "event_id": "789",
    "comment_id": "101"
  }
}
```

---

## Discover Endpoints

Public endpoints for discovering content on the platform. No authentication required.

### GET /discover/bands

Get paginated list of all bands.

**Authentication:** None

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "bands": [
    {
      "id": 1,
      "slug": "band-name",
      "name": "Band Name",
      "city": "New York",
      "region": "New York",
      "location": "New York, New York",
      "latitude": 40.7128,
      "longitude": -74.006,
      "spotify_link": "https://open.spotify.com/artist/...",
      "bandcamp_link": "https://bandname.bandcamp.com",
      "apple_music_link": null,
      "youtube_music_link": null,
      "about": "We make great music",
      "profile_picture_url": "https://...",
      "reviews_count": 5,
      "user_owned": true,
      "owner": { "id": 1, "username": "johndoe" },
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 150,
    "total_pages": 8,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

### GET /discover/users

Get paginated list of all active fan users who have completed onboarding (excludes band accounts).

**Authentication:** None

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "users": [
    {
      "id": 1,
      "username": "johndoe",
      "display_name": "johndoe",
      "role": "fan",
      "about_me": "Music lover",
      "profile_image_url": "https://...",
      "location": "Los Angeles, California",
      "reviews_count": 10,
      "bands_count": 2,
      "followers_count": 25,
      "following_count": 12
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 500,
    "total_pages": 25,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

### GET /discover/reviews

Get paginated list of all reviews (from active users only).

**Authentication:** None

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "band_name": "Artist Name",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "band": { ... },
      "author": {
        "id": 1,
        "username": "johndoe",
        "profile_image_url": "https://..."
      },
      "likes_count": 8,
      "liked_by_current_user": false,
      "comments_count": 2,
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 1000,
    "total_pages": 50,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

### GET /discover/events

Get paginated list of upcoming events. Includes both band events (from active bands) and standalone events (no band).

**Authentication:** None

**Query Parameters:**

- `q` (optional): Search by band name (only matches events with a band)
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "events": [
    {
      "id": 1,
      "name": "Summer Tour Kickoff",
      "description": "Join us for the first show!",
      "event_date": "2025-07-15T20:00:00.000Z",
      "ticket_link": "https://tickets.example.com/event/123",
      "image_url": "https://...",
      "price": "$25",
      "age_restriction": "21+",
      "venue": {
        "id": 1,
        "name": "The Roxy",
        "address": "9009 Sunset Blvd",
        "city": "West Hollywood",
        "region": "California",
        "latitude": 34.0901,
        "longitude": -118.3868
      },
      "band": {
        "id": 1,
        "slug": "band-name",
        "name": "Band Name",
        "location": "Los Angeles, California",
        "profile_picture_url": "https://...",
        "reviews_count": 5,
        "user_owned": true
      },
      "user_id": 1,
      "created_at": "2025-01-01T00:00:00.000Z",
      "updated_at": "2025-01-01T00:00:00.000Z"
    },
    {
      "id": 2,
      "name": "Open Mic Night",
      "band": null,
      "user_id": 5,
      "...": "..."
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 50,
    "total_pages": 3,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

**Notes:**
- Returns active, upcoming events sorted by `event_date` ascending
- When searching by `q`, only events with a matching band name are returned (band-less events are excluded from band-name search)
- Without a search query, both band and non-band events are returned
- Events belonging to disabled bands are excluded

---

### GET /discover/search

Unified search across bands, users, reviews, and events.

**Authentication:** None

**Query Parameters:**

- `q` (required): Search query
- `limit` (optional): Max results per category (default: 5, max: 20)

**Response (200 OK):**

```json
{
  "results": {
    "bands": [ { "...": "..." } ],
    "users": [ { "...": "..." } ],
    "reviews": [ { "...": "..." } ],
    "events": [ { "...": "..." } ]
  },
  "query": "band name",
  "counts": {
    "bands": 3,
    "users": 1,
    "reviews": 5,
    "events": 2
  }
}
```

**Notes:**
- Bands: searched by name using trigram similarity
- Users: searched by username (active fan users only)
- Reviews: searched by band name or song name
- Events: searched by band name (band-less events excluded from search results)

---

## Dashboard Endpoints

Dashboard endpoints provide combined data for efficient page loading.

### GET /api/v1/fan_dashboard

Get all fan dashboard data in a single optimized request. Reduces 17+ API calls to 1.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "profile": {
    "id": 1,
    "username": "johndoe",
    "email": "user@example.com",
    "about_me": "Music lover",
    "profile_image_url": "https://...",
    "role": "fan",
    "display_name": "johndoe",
    "location": "Los Angeles, California",
    "followers_count": 25,
    "following_count": 12,
    "reviews_count": 10,
    "lastfm_connected": true,
    "lastfm_username": "johndoe_lastfm",
    "email_confirmed": true,
    "admin": false
  },
  "unread_notifications_count": 3,
  "recent_reviews": [
    {
      "id": 1,
      "song_name": "Song Title",
      "band_name": "Artist Name",
      "artwork_url": "https://...",
      "created_at": "2024-12-01T00:00:00Z",
      "likes_count": 5,
      "comments_count": 2
    }
  ],
  "recently_played": [
    {
      "name": "Song Name",
      "artist": "Artist Name",
      "album": "Album Name",
      "played_at": "2024-12-01T00:00:00Z",
      "now_playing": false,
      "source": "lastfm",
      "album_art_url": "https://..."
    }
  ],
  "following_feed_preview": [
    {
      "type": "review",
      "data": {
        "id": 1,
        "song_name": "Song Title",
        "band_name": "Artist Name",
        "artwork_url": "https://...",
        "review_text": "Great song! This is a truncated preview...",
        "author": {
          "id": 2,
          "username": "followeduser",
          "display_name": "Followed User",
          "profile_image_url": "https://..."
        },
        "created_at": "2024-12-01T00:00:00Z",
        "likes_count": 3
      }
    },
    {
      "type": "post",
      "data": {
        "id": 5,
        "title": "My Latest Album Review",
        "slug": "my-latest-album-review",
        "excerpt": "A deep dive into the new release...",
        "author": {
          "id": 3,
          "username": "musicblogger",
          "display_name": "Music Blogger",
          "profile_image_url": "https://..."
        },
        "created_at": "2024-12-01T00:00:00Z"
      }
    },
    {
      "type": "event",
      "data": {
        "id": 10,
        "title": "Live at the Roxy",
        "start_date": "2024-12-15T20:00:00Z",
        "venue": "The Roxy",
        "author": {
          "id": 4,
          "username": "bandaccount",
          "display_name": "Band Account",
          "profile_image_url": "https://..."
        },
        "created_at": "2024-12-01T00:00:00Z"
      }
    }
  ],
  "favorite_bands": [
    {
      "id": 1,
      "name": "Band Name",
      "slug": "band-name",
      "image_url": "https://...",
      "position": 1
    }
  ],
  "stats": {
    "total_scrobbles": 1234,
    "scrobbles_this_week": 45
  }
}
```

**Response Fields:**

- `profile` - Current user profile data (uses counter caches for counts)
- `unread_notifications_count` - Number of unread notifications
- `recent_reviews` - User's 5 most recent reviews
- `recently_played` - Last 10 tracks from all connected sources (Last.fm, scrobbles)
- `following_feed_preview` - First 5 items from combined feed: user's own reviews, posts, and events + content from followed users + reviews about bands owned by followed users. Each item is a `{ type, data }` object where type is `"review"`, `"post"`, or `"event"` (review text truncated to 150 chars)
- `favorite_bands` - User's top 5 favorite bands (if feature enabled)
- `stats` - Scrobble statistics (total and this week)

**Notes:**

- This endpoint is optimized for the fan dashboard page
- Uses counter caches instead of COUNT queries for followers/following/reviews
- All sub-queries use eager loading to minimize database calls
- `recently_played` returns empty array if Last.fm is not connected and no local scrobbles exist
- `favorite_bands` returns empty array if the feature is not yet enabled

---

### GET /api/v1/blogger_dashboard

Get all blogger dashboard data in a single optimized request.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "profile": {
    "id": 1,
    "username": "musicblogger",
    "email": "blogger@example.com",
    "about_me": "Music writer and critic",
    "profile_image_url": "https://...",
    "role": "blogger",
    "plan": {
      "key": "blogger",
      "name": "Blogger"
    },
    "abilities": ["create_blog_post", "attach_images", "draft_posts", "manage_tags", "..."],
    "display_name": "musicblogger",
    "location": "New York, NY",
    "followers_count": 150,
    "following_count": 45,
    "reviews_count": 25,
    "posts_count": 12,
    "lastfm_connected": false,
    "lastfm_username": null,
    "email_confirmed": true,
    "admin": false,
    "preferred_streaming_platform": "spotify"
  },
  "unread_notifications_count": 5,
  "recent_reviews": [
    {
      "id": 1,
      "song_name": "Song Title",
      "band_name": "Artist Name",
      "artwork_url": "https://...",
      "created_at": "2026-02-25T00:00:00Z",
      "likes_count": 8,
      "comments_count": 3
    }
  ],
  "recently_played": [],
  "following_feed_preview": [
    {
      "type": "review",
      "data": {
        "id": 1,
        "song_name": "Song Title",
        "band_name": "Artist Name",
        "artwork_url": "https://...",
        "review_text": "Great song! This is a truncated preview...",
        "author": {
          "id": 2,
          "username": "followeduser",
          "display_name": "Followed User",
          "profile_image_url": "https://..."
        },
        "created_at": "2026-02-25T00:00:00Z",
        "likes_count": 3,
        "comments_count": 1,
        "liked_by_current_user": false
      }
    },
    {
      "type": "post",
      "data": {
        "id": 5,
        "title": "My Latest Album Review",
        "slug": "my-latest-album-review",
        "excerpt": "A deep dive into the new release...",
        "author": {
          "id": 3,
          "username": "musicblogger",
          "display_name": "Music Blogger",
          "profile_image_url": "https://..."
        },
        "created_at": "2026-02-25T00:00:00Z"
      }
    },
    {
      "type": "event",
      "data": {
        "id": 10,
        "title": "Live at the Roxy",
        "start_date": "2026-03-15T20:00:00Z",
        "venue": "The Roxy",
        "author": {
          "id": 4,
          "username": "bandaccount",
          "display_name": "Band Account",
          "profile_image_url": "https://..."
        },
        "created_at": "2026-02-25T00:00:00Z"
      }
    }
  ],
  "recent_posts": [
    {
      "id": 1,
      "title": "My Latest Album Review",
      "slug": "my-latest-album-review",
      "excerpt": "A deep dive into the new release...",
      "status": "published",
      "featured": true,
      "publish_date": "2026-02-25T10:00:00Z",
      "created_at": "2026-02-24T15:00:00Z",
      "updated_at": "2026-02-25T09:00:00Z"
    },
    {
      "id": 2,
      "title": "Draft: Upcoming Concert Preview",
      "slug": "draft-upcoming-concert-preview",
      "excerpt": null,
      "status": "draft",
      "featured": false,
      "publish_date": null,
      "created_at": "2026-02-25T08:00:00Z",
      "updated_at": "2026-02-25T08:00:00Z"
    }
  ],
  "posts_stats": {
    "total_posts": 12,
    "published_posts": 8,
    "draft_posts": 3,
    "scheduled_posts": 1
  }
}
```

**Response Fields:**

- `profile` - Current user profile data including `posts_count`
- `unread_notifications_count` - Number of unread notifications
- `recent_reviews` - User's 5 most recent song reviews
- `recently_played` - Always empty array for bloggers (they don't use scrobbling)
- `following_feed_preview` - First 5 items from combined feed (user's own + followed users' reviews, posts, and events). Each item is a `{ type, data }` object where type is `"review"`, `"post"`, or `"event"`
- `recent_posts` - User's 5 most recent blog posts (all statuses)
- `posts_stats` - Post counts by status (total, published, draft, scheduled)

**Notes:**

- This endpoint is optimized for the blogger dashboard page
- Returns the same base format as fan_dashboard for frontend compatibility
- `recently_played` is always empty (bloggers focus on posts, not scrobbling)
- `recent_posts` includes drafts and scheduled posts (only visible to the owner)

---

## Last.fm Integration Endpoints

### POST /lastfm/connect

Connect a Last.fm account by username.

**Authentication:** Required

**Request Body:**

```json
{
  "username": "lastfm_username"
}
```

**Response (200 OK):**

```json
{
  "message": "Last.fm account connected successfully",
  "username": "lastfm_username",
  "profile": {
    "name": "lastfm_username",
    "realname": "John Doe",
    "url": "https://www.last.fm/user/lastfm_username",
    "playcount": "12345",
    "image": "https://..."
  }
}
```

**Error Response (400 Bad Request):**

```json
{
  "error": "Last.fm username is required"
}
```

or

```json
{
  "error": "Last.fm user not found"
}
```

---

### DELETE /lastfm/disconnect

Disconnect Last.fm account.

**Authentication:** Required

**Response (200 OK):**

```json
{
  "message": "Last.fm account disconnected successfully"
}
```

---

### GET /lastfm/status

Check Last.fm connection status.

**Authentication:** Required

**Response (200 OK) - When connected:**

```json
{
  "connected": true,
  "username": "lastfm_username",
  "profile": {
    "name": "lastfm_username",
    "realname": "John Doe",
    "url": "https://www.last.fm/user/lastfm_username",
    "playcount": "12345",
    "image": "https://..."
  }
}
```

**Response (200 OK) - When not connected:**

```json
{
  "connected": false,
  "username": null
}
```

---

### GET /lastfm/search-artist

Search for artists on Last.fm.

**Authentication:** Required

**Query Parameters:**

- `query` (required): Artist name to search for
- `limit` (optional): Number of results to return (default: 10)

**Response (200 OK):**

```json
{
  "artists": [
    {
      "name": "Artist Name",
      "mbid": "musicbrainz-id",
      "url": "https://www.last.fm/music/Artist+Name",
      "image": "https://..."
    }
  ]
}
```

**Error Response (400 Bad Request):**

```json
{
  "error": "Search query is required"
}
```

---

## Scrobble Endpoints

All scrobble endpoints are namespaced under `/api/v1`. Scrobbles represent track listening history.

### POST /api/v1/scrobbles

Submit scrobbles (batch). Duplicates (same track/artist/played_at within 30 seconds) are silently skipped.

**Authentication:** Required

**Rate Limit:** 100 submissions per hour per user

**Request Body:**

```json
{
  "scrobbles": [
    {
      "track_name": "Song Title",
      "artist_name": "Artist Name",
      "album_name": "Album Name",
      "duration_ms": 240000,
      "played_at": "2025-01-15T20:30:00Z",
      "source_app": "goodsongs-android",
      "source_device": "Pixel 8",
      "album_artist": "Various Artists",
      "genre": "Rock",
      "year": 2024,
      "release_date": "2024-03-15",
      "artwork_uri": "https://i.scdn.co/image/abc123",
      "album_art": "data:image/jpeg;base64,/9j/4AAQ..."
    }
  ]
}
```

**Fields:**

- `track_name` (required): Track name (max 500 chars)
- `artist_name` (required): Artist name (max 500 chars)
- `album_name` (optional): Album name (max 500 chars)
- `duration_ms` (required): Track duration in milliseconds (minimum 30000)
- `played_at` (required): ISO 8601 timestamp, must be within the last 14 days and not in the future
- `source_app` (required): Submitting application identifier (max 100 chars)
- `source_device` (optional): Device identifier (max 100 chars)
- `album_artist` (optional): Album artist, useful for compilation albums (max 500 chars)
- `genre` (optional): Track/album genre from METADATA_KEY_GENRE (max 100 chars)
- `year` (optional): 4-digit release year (1800-2100)
- `release_date` (optional): Full release date in YYYY-MM-DD format
- `artwork_uri` (optional): External artwork URL (e.g., Spotify CDN URL, max 2000 chars) - highest priority for artwork display
- `album_art` (optional): Base64-encoded album artwork image (JPEG/PNG/WebP, max 5MB). Supports both raw base64 and data URI format (`data:image/jpeg;base64,...`)

**Artwork Priority (highest to lowest):**

1. `artwork_uri` - External URL from Android (e.g., Spotify CDN)
2. `album_art` - Base64-encoded bitmap uploaded to Active Storage
3. `preferred_artwork_url` - User-selected override (set via PATCH endpoint)
4. `track.album.cover_art_url` - Enrichment fallback from MusicBrainz/Cover Art Archive

Maximum 50 scrobbles per request.

**Response (201 Created):**

```json
{
  "data": {
    "accepted": 1,
    "rejected": 0,
    "scrobbles": [
      {
        "id": 1,
        "track_name": "Song Title",
        "artist_name": "Artist Name",
        "album_name": "Album Name",
        "played_at": "2025-01-15T20:30:00Z",
        "metadata_status": "pending",
        "artwork_url": "https://i.scdn.co/image/abc123",
        "genre": "Rock",
        "year": 2024,
        "album_artist": "Various Artists"
      }
    ]
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "One or more scrobbles failed validation",
    "details": [
      {
        "index": 0,
        "errors": [{ "field": "track_name", "message": "can't be blank" }]
      }
    ]
  }
}
```

**Error Response (422 Unprocessable Entity) - Batch too large:**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Maximum 50 scrobbles per request"
  }
}
```

**Error Response (429 Too Many Requests):**

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Too many scrobble submissions. Maximum 100 per hour.",
    "details": {
      "retry_after": 1705363200
    }
  }
}
```

---

### POST /api/v1/scrobbles/from_lastfm

Convert a Last.fm track to a scrobble with preferred artwork. Use this when a user selects alternative artwork for a Last.fm track in their recently played feed.

**Authentication:** Required

**Request Body:**

```json
{
  "scrobble": {
    "track_name": "Karma Police",
    "artist_name": "Radiohead",
    "album_name": "OK Computer",
    "played_at": "2026-02-19T10:30:00Z",
    "preferred_artwork_url": "https://coverartarchive.org/release/abc123/front.jpg",
    "artwork_uri": "https://lastfm.freetls.fastly.net/i/u/300x300/abc123.png",
    "lastfm_url": "https://www.last.fm/music/Radiohead/_/Karma+Police",
    "lastfm_loved": true,
    "musicbrainz_recording_id": "uuid-here",
    "artist_mbid": "artist-uuid",
    "album_mbid": "album-uuid"
  }
}
```

**Fields:**

- `track_name` (required): Track name from Last.fm
- `artist_name` (required): Artist name from Last.fm
- `album_name` (optional): Album name from Last.fm
- `played_at` (required): ISO 8601 timestamp when the track was played
- `preferred_artwork_url` (optional): User-selected artwork URL (from artwork search)
- `artwork_uri` (optional): Original Last.fm artwork URL (as fallback)
- `lastfm_url` (optional): Last.fm track URL
- `lastfm_loved` (optional): Whether the track is loved on Last.fm
- `musicbrainz_recording_id` (optional): MusicBrainz recording ID from Last.fm
- `artist_mbid` (optional): MusicBrainz artist ID from Last.fm
- `album_mbid` (optional): MusicBrainz album ID from Last.fm

**Notes:**

- `duration_ms` is not required (Last.fm doesn't provide it)
- `played_at` can be older than 14 days (unlike regular scrobbles)
- If a duplicate scrobble exists (same track/artist within 30 seconds), the existing scrobble is updated with the new preferred artwork

**Response (201 Created):**

```json
{
  "data": {
    "message": "Last.fm track converted to scrobble",
    "scrobble": {
      "id": "uuid-here",
      "track_name": "Karma Police",
      "artist_name": "Radiohead",
      "album_name": "OK Computer",
      "played_at": "2026-02-19T10:30:00Z",
      "artwork_url": "https://coverartarchive.org/release/abc123/front.jpg",
      "preferred_artwork_url": "https://coverartarchive.org/release/abc123/front.jpg",
      "has_preferred_artwork": true,
      "metadata_status": "pending"
    }
  }
}
```

**Response (200 OK) - Duplicate updated:**

```json
{
  "data": {
    "message": "Scrobble already exists, updated artwork",
    "scrobble": {
      "id": "existing-uuid",
      "track_name": "Karma Police",
      "artwork_url": "https://coverartarchive.org/release/abc123/front.jpg",
      "has_preferred_artwork": true
    }
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "track_name and artist_name are required"
  }
}
```

---

### GET /api/v1/scrobbles

Get the current user's scrobbles with cursor-based pagination.

**Authentication:** Required

**Query Parameters:**

- `since` (optional): ISO 8601 timestamp, return scrobbles after this time
- `until` (optional): ISO 8601 timestamp, return scrobbles before this time
- `cursor` (optional): ISO 8601 timestamp cursor for pagination
- `limit` (optional): Number of results (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "data": {
    "scrobbles": [
      {
        "id": 1,
        "track_name": "Song Title",
        "artist_name": "Artist Name",
        "album_name": "Album Name",
        "played_at": "2025-01-15T20:30:00Z",
        "source_app": "goodsongs-ios",
        "artwork_url": "https://i.scdn.co/image/abc123",
        "genre": "Rock",
        "year": 2024,
        "album_artist": "Various Artists",
        "track": {
          "id": 10,
          "name": "Song Title",
          "duration_ms": 240000,
          "artist": {
            "id": 5,
            "name": "Artist Name",
            "image_url": "https://..."
          },
          "album": {
            "id": 3,
            "name": "Album Name",
            "cover_art_url": "https://..."
          },
          "streaming_links": {
            "spotify": "https://open.spotify.com/track/...",
            "appleMusic": "https://music.apple.com/us/album/...",
            "youtubeMusic": "https://music.youtube.com/watch?v=...",
            "tidal": "https://tidal.com/track/...",
            "amazonMusic": "https://music.amazon.com/albums/...",
            "deezer": "https://www.deezer.com/track/...",
            "soundcloud": "https://soundcloud.com/...",
            "bandcamp": "https://artist.bandcamp.com/track/..."
          },
          "songlink_url": "https://song.link/..."
        }
      }
    ],
    "pagination": {
      "next_cursor": "2025-01-15T20:30:00Z",
      "has_more": true
    }
  }
}
```

**Response Fields:**

- `artwork_url` - Resolved artwork URL using the priority system (artwork_uri > album_art > preferred_artwork_url > track.album.cover_art_url)
- `genre` - Genre metadata from Android client (if provided)
- `year` - Release year metadata from Android client (if provided)
- `album_artist` - Album artist metadata from Android client (if provided)
- `track.streaming_links` - Object containing streaming platform URLs (spotify, appleMusic, youtubeMusic, tidal, amazonMusic, deezer, soundcloud, bandcamp). Only platforms where the track is available are included. Empty object `{}` if not yet fetched or track not found on any platform.
- `track.songlink_url` - Universal song.link URL that redirects users to their preferred streaming platform

Note: The `track` field is `null` when metadata enrichment has not yet completed. Streaming links are fetched asynchronously after the track's ISRC code is obtained.

---

### GET /api/v1/scrobbles/recent

Get the current user's recent scrobbles. Cached for 60 seconds.

**Authentication:** Required

**Query Parameters:**

- `limit` (optional): Number of results (default: 20, max: 50)

**Response (200 OK):**

```json
{
  "data": {
    "scrobbles": [
      {
        "id": 1,
        "track_name": "Song Title",
        "artist_name": "Artist Name",
        "album_name": "Album Name",
        "played_at": "2025-01-15T20:30:00Z",
        "source_app": "goodsongs-ios",
        "track": null
      }
    ]
  }
}
```

---

### GET /api/v1/users/:user_id/scrobbles

Get scrobbles for a specific user with cursor-based pagination.

**Authentication:** Required

**Query Parameters:**

- `since` (optional): ISO 8601 timestamp, return scrobbles after this time
- `until` (optional): ISO 8601 timestamp, return scrobbles before this time
- `cursor` (optional): ISO 8601 timestamp cursor for pagination
- `limit` (optional): Number of results (default: 20, max: 100)

**Response (200 OK):**
Same format as `GET /api/v1/scrobbles`.

---

### DELETE /api/v1/scrobbles/:id

Delete a scrobble (owner only).

**Authentication:** Required

**Response (204 No Content)**

---

### PATCH /api/v1/scrobbles/:id/artwork

Set preferred artwork for a scrobble. This overrides the automatically fetched album artwork.

**Authentication:** Required (owner only)

**Request Body:**

```json
{
  "artwork_url": "https://example.com/preferred-artwork.jpg"
}
```

**Response (200 OK):**

```json
{
  "data": {
    "message": "Preferred artwork set successfully",
    "scrobble": {
      "id": "uuid",
      "track_name": "Song Title",
      "artist_name": "Artist Name",
      "album_name": "Album Name",
      "played_at": "2025-01-15T20:30:00Z",
      "artwork_url": "https://example.com/preferred-artwork.jpg",
      "preferred_artwork_url": "https://example.com/preferred-artwork.jpg",
      "has_preferred_artwork": true,
      "metadata_status": "enriched"
    }
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "artwork_url is required"
  }
}
```

**Notes:**

- Use with `GET /artwork/search` to let users choose from available artwork options
- The `artwork_url` should be a valid image URL from one of the artwork sources
- This overrides the album's cover art for this specific scrobble only

---

### DELETE /api/v1/scrobbles/:id/artwork

Clear the preferred artwork for a scrobble, reverting to the album's cover art.

**Authentication:** Required (owner only)

**Response (200 OK):**

```json
{
  "data": {
    "message": "Preferred artwork cleared",
    "scrobble": {
      "id": "uuid",
      "track_name": "Song Title",
      "artist_name": "Artist Name",
      "album_name": "Album Name",
      "played_at": "2025-01-15T20:30:00Z",
      "artwork_url": "https://coverartarchive.org/...",
      "preferred_artwork_url": null,
      "has_preferred_artwork": false,
      "metadata_status": "enriched"
    }
  }
}
```

---

## Admin Endpoints

### GET /admin/users

Get paginated list of all users (admin only).

**Authentication:** Required (Admin only)

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "users": [
    {
      "id": 1,
      "username": "johndoe",
      "email": "user@example.com",
      "about_me": "Music lover",
      "profile_image_url": "https://...",
      "reviews_count": 10,
      "bands_count": 2,
      "role": "fan",
      "onboarding_completed": true,
      "display_name": "johndoe",
      "admin": false,
      "disabled": false
    },
    {
      "id": 2,
      "username": null,
      "email": "band@example.com",
      "about_me": null,
      "profile_image_url": null,
      "reviews_count": 0,
      "bands_count": 1,
      "role": "band",
      "onboarding_completed": true,
      "display_name": "The Band Name",
      "admin": false,
      "disabled": true,
      "primary_band": {
        "id": 1,
        "slug": "the-band-name",
        "name": "The Band Name",
        "location": "New York",
        "profile_picture_url": "https://...",
        "reviews_count": 5,
        "user_owned": true
      }
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 150,
    "total_pages": 8,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "Admin access required"
}
```

---

### GET /admin/users/:id

Get a single user's full profile with all editable fields, reviews, and bands (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "about_me": "Music lover",
    "city": "Los Angeles",
    "region": "California",
    "location": "Los Angeles, California",
    "latitude": 34.0522,
    "longitude": -118.2437,
    "role": "fan",
    "onboarding_completed": true,
    "admin": false,
    "disabled": false,
    "lastfm_username": "johndoe_lastfm",
    "lastfm_connected": true,
    "profile_image_url": "https://...",
    "display_name": "johndoe",
    "reviews_count": 10,
    "bands_count": 2,
    "followers_count": 25,
    "following_count": 12,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  },
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "band_name": "Artist Name",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "band": { ... },
      "author": { ... },
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "bands": [
    {
      "id": 1,
      "slug": "user-band",
      "name": "User Band",
      "city": "Los Angeles",
      "region": "California",
      "location": "Los Angeles, California",
      "disabled": false,
      ...
    }
  ]
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "Admin access required"
}
```

**Error Response (404 Not Found):**

```json
{
  "error": "Record not found"
}
```

---

### PATCH /admin/users/:id

Update any user's profile (admin only).

**Authentication:** Required (Admin only)

**Request Body:**

```json
{
  "email": "newemail@example.com",
  "username": "newusername",
  "about_me": "Updated bio",
  "city": "New York",
  "region": "New York",
  "admin": true,
  "disabled": false,
  "role": "fan",
  "plan_id": 3,
  "lastfm_username": "lastfm_user",
  "onboarding_completed": true
}
```

All fields are optional. For file upload (profile_image), use `multipart/form-data`.

**Editable Fields:**

- `email` - User's email address
- `username` - Username (required for fan accounts)
- `about_me` - Bio text (max 500 chars)
- `city` - City location (max 100 chars)
- `region` - Region/state/country (max 100 chars)
- `admin` - Admin status (cannot modify your own admin status)
- `disabled` - Account disabled status
- `role` - "fan", "band", or "blogger"
- `plan_id` - Assign a subscription plan by ID (use GET /admin/plans to list available plans)
- `lastfm_username` - Connected Last.fm username
- `onboarding_completed` - Onboarding status
- `profile_image` - Profile image file (multipart/form-data)

**Response (200 OK):**

```json
{
  "message": "User has been updated",
  "user": {
    "id": 1,
    "email": "newemail@example.com",
    "username": "newusername",
    "about_me": "Updated bio",
    "city": "New York",
    "region": "New York",
    "location": "New York, New York",
    "latitude": 40.7128,
    "longitude": -74.006,
    "role": "fan",
    "plan": {
      "id": 3,
      "key": "band_starter",
      "name": "Band Starter"
    },
    "abilities": ["create_recommendation", "follow_users", "create_comments", "manage_band_profile", "upload_music", "view_analytics", "manage_storefront", "send_newsletter", "manage_events", "custom_design", "create_blog_post", "attach_images", "attach_songs", "draft_posts", "manage_tags", "rss_feed"],
    "onboarding_completed": true,
    "admin": true,
    "disabled": false,
    "lastfm_username": "lastfm_user",
    "lastfm_connected": true,
    "profile_image_url": "https://...",
    "display_name": "newusername",
    "reviews_count": 10,
    "bands_count": 2,
    "followers_count": 25,
    "following_count": 12,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "errors": ["Email has already been taken"]
}
```

**Error Response (422 Unprocessable Entity) - Self admin modification:**

```json
{
  "error": "You cannot modify your own admin status"
}
```

---

### PATCH /admin/users/:id/toggle-disabled

Toggle a user's disabled status (admin only). Disabled users cannot login and their profiles/reviews are hidden from public pages.

**Authentication:** Required (Admin only)

**Response (200 OK) - When disabling:**

```json
{
  "message": "User has been disabled",
  "user": {
    "id": 1,
    "username": "johndoe",
    "email": "user@example.com",
    "about_me": "Music lover",
    "profile_image_url": "https://...",
    "reviews_count": 10,
    "bands_count": 2,
    "role": "fan",
    "onboarding_completed": true,
    "display_name": "johndoe",
    "admin": false,
    "disabled": true
  }
}
```

**Response (200 OK) - When enabling:**

```json
{
  "message": "User has been enabled",
  "user": {
    "id": 1,
    "username": "johndoe",
    "disabled": false,
    ...
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You cannot disable your own account"
}
```

**Error Response (403 Forbidden):**

```json
{
  "error": "Admin access required"
}
```

---

### DELETE /admin/users/:id

Delete a user and all their associated data (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "message": "User has been deleted"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "error": "You cannot delete your own account"
}
```

---

### GET /admin/bands

Get paginated list of all bands including disabled ones (admin only).

**Authentication:** Required (Admin only)

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "bands": [
    {
      "id": 1,
      "slug": "band-name",
      "name": "Band Name",
      "city": "New York",
      "region": "New York",
      "location": "New York, New York",
      "latitude": 40.7128,
      "longitude": -74.006,
      "spotify_link": "https://open.spotify.com/artist/...",
      "bandcamp_link": "https://bandname.bandcamp.com",
      "apple_music_link": null,
      "youtube_music_link": null,
      "musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
      "lastfm_artist_name": "Band Name",
      "lastfm_url": "https://www.last.fm/music/Band+Name",
      "about": "We make great music",
      "profile_picture_url": "https://...",
      "reviews_count": 5,
      "user_owned": true,
      "owner": { "id": 1, "username": "johndoe" },
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z",
      "disabled": false
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 500,
    "total_pages": 25,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

### GET /admin/bands/:id

Get a single band's full profile with all editable fields, reviews, and events (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "band": {
    "id": 1,
    "name": "Band Name",
    "slug": "band-name",
    "about": "We make great music",
    "city": "New York",
    "region": "New York",
    "location": "New York, New York",
    "latitude": 40.7128,
    "longitude": -74.006,
    "disabled": false,
    "user_id": 1,
    "user_owned": true,
    "owner": {
      "id": 1,
      "username": "johndoe",
      "email": "johndoe@example.com"
    },
    "spotify_link": "https://open.spotify.com/artist/...",
    "bandcamp_link": "https://bandname.bandcamp.com",
    "apple_music_link": null,
    "youtube_music_link": null,
    "musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
    "lastfm_artist_name": "Band Name",
    "lastfm_url": "https://www.last.fm/music/Band+Name",
    "artist_image_url": "https://...",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "events_count": 3,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  },
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "band_name": "Band Name",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "band": { ... },
      "author": { ... },
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "events": [
    {
      "id": 1,
      "name": "Summer Tour",
      "description": "Join us for the tour!",
      "event_date": "2025-07-15T20:00:00.000Z",
      "venue": { ... },
      "band": { ... },
      "created_at": "2025-01-01T00:00:00.000Z",
      "updated_at": "2025-01-01T00:00:00.000Z"
    }
  ]
}
```

**Error Response (404 Not Found):**

```json
{
  "error": "Record not found"
}
```

---

### PATCH /admin/bands/:id

Update any band's information (admin only).

**Authentication:** Required (Admin only)

**Request Body:**

```json
{
  "name": "New Band Name",
  "slug": "new-band-name",
  "about": "Updated description",
  "city": "Los Angeles",
  "region": "California",
  "disabled": false,
  "user_id": 2,
  "spotify_link": "https://open.spotify.com/artist/...",
  "bandcamp_link": "https://newband.bandcamp.com",
  "apple_music_link": "https://music.apple.com/...",
  "youtube_music_link": "https://music.youtube.com/...",
  "musicbrainz_id": "new-mbid",
  "lastfm_artist_name": "New Band Name",
  "artist_image_url": "https://..."
}
```

All fields are optional. For file upload (profile_picture), use `multipart/form-data`.

**Editable Fields:**

- `name` - Band name
- `slug` - URL slug
- `about` - Band description
- `city` - City location (max 100 chars)
- `region` - Region/state/country (max 100 chars)
- `disabled` - Band disabled status
- `user_id` - Owner user ID (reassign ownership)
- `spotify_link` - Spotify artist URL
- `bandcamp_link` - Bandcamp URL
- `apple_music_link` - Apple Music URL
- `youtube_music_link` - YouTube Music URL
- `musicbrainz_id` - MusicBrainz artist ID
- `lastfm_artist_name` - Last.fm artist name
- `artist_image_url` - Artist image URL (from Last.fm/MusicBrainz)
- `profile_picture` - Profile picture file (multipart/form-data)

**Response (200 OK):**

```json
{
  "message": "Band has been updated",
  "band": {
    "id": 1,
    "name": "New Band Name",
    "slug": "new-band-name",
    "about": "Updated description",
    "city": "Los Angeles",
    "region": "California",
    "location": "Los Angeles, California",
    "latitude": 34.0522,
    "longitude": -118.2437,
    "disabled": false,
    "user_id": 2,
    "user_owned": true,
    "owner": {
      "id": 2,
      "username": "newowner",
      "email": "newowner@example.com"
    },
    "spotify_link": "https://open.spotify.com/artist/...",
    "bandcamp_link": "https://newband.bandcamp.com",
    "apple_music_link": "https://music.apple.com/...",
    "youtube_music_link": "https://music.youtube.com/...",
    "musicbrainz_id": "new-mbid",
    "lastfm_artist_name": "New Band Name",
    "lastfm_url": "https://www.last.fm/music/New+Band+Name",
    "artist_image_url": "https://...",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "events_count": 3,
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "errors": ["Name has already been taken"]
}
```

---

### PATCH /admin/bands/:id/toggle-disabled

Toggle a band's disabled status (admin only). Disabled bands are hidden from public pages.

**Authentication:** Required (Admin only)

**Response (200 OK) - When disabling:**

```json
{
  "message": "Band has been disabled",
  "band": {
    "id": 1,
    "slug": "band-name",
    "name": "Band Name",
    "disabled": true,
    ...
  }
}
```

**Response (200 OK) - When enabling:**

```json
{
  "message": "Band has been enabled",
  "band": {
    "id": 1,
    "slug": "band-name",
    "name": "Band Name",
    "disabled": false,
    ...
  }
}
```

---

### DELETE /admin/bands/:id

Delete a band and all its reviews (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "message": "Band has been deleted"
}
```

---

### GET /admin/reviews

Get paginated list of all reviews (admin only).

**Authentication:** Required (Admin only)

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "reviews": [
    {
      "id": 1,
      "song_link": "https://open.spotify.com/track/...",
      "band_name": "Artist Name",
      "song_name": "Song Title",
      "artwork_url": "https://...",
      "review_text": "Great song!",
      "liked_aspects": ["melody", "lyrics"],
      "band": { ... },
      "author": {
        "id": 1,
        "username": "johndoe",
        "profile_image_url": "https://..."
      },
      "likes_count": 5,
      "liked_by_current_user": false,
      "comments_count": 1,
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 1000,
    "total_pages": 50,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

---

### DELETE /admin/reviews/:id

Delete a review (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "message": "Review has been deleted"
}
```

---

### GET /admin/plans

Get all plans with summary information (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "plans": [
    {
      "id": 1,
      "key": "fan_free",
      "name": "Fan Free",
      "role": "fan",
      "price_cents_monthly": 0,
      "price_cents_annual": 0,
      "active": true,
      "abilities_count": 4,
      "created_at": "2026-02-23T00:00:00.000Z",
      "updated_at": "2026-02-23T00:00:00.000Z"
    },
    {
      "id": 2,
      "key": "band_free",
      "name": "Band Free",
      "role": "band",
      "price_cents_monthly": 0,
      "price_cents_annual": 0,
      "active": true,
      "abilities_count": 5,
      "created_at": "2026-02-23T00:00:00.000Z",
      "updated_at": "2026-02-23T00:00:00.000Z"
    }
  ]
}
```

---

### GET /admin/plans/:id

Get a single plan with its abilities (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "plan": {
    "id": 1,
    "key": "blogger_pro",
    "name": "Blogger Pro",
    "role": "blogger",
    "price_cents_monthly": 1800,
    "price_cents_annual": 18000,
    "active": true,
    "abilities_count": 23,
    "created_at": "2026-02-23T00:00:00.000Z",
    "updated_at": "2026-02-23T00:00:00.000Z",
    "abilities": [
      {
        "key": "create_blog_post",
        "name": "Create Blog Post",
        "category": "content"
      },
      {
        "key": "schedule_post",
        "name": "Schedule Posts",
        "category": "content"
      }
    ]
  }
}
```

---

### PATCH /admin/plans/:id

Update a plan's details (admin only).

**Authentication:** Required (Admin only)

**Request Body:**

```json
{
  "name": "Blogger Pro Plus",
  "price_cents_monthly": 2000,
  "price_cents_annual": 20000,
  "active": true
}
```

All fields are optional.

**Editable Fields:**

- `name` - Display name of the plan
- `price_cents_monthly` - Monthly price in cents
- `price_cents_annual` - Annual price in cents
- `active` - Whether plan is available for new signups

**Response (200 OK):**

```json
{
  "message": "Plan updated successfully",
  "plan": { ... }
}
```

---

### GET /admin/plans/compare

Side-by-side comparison matrix of all plans and abilities (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "plans": [
    { "key": "fan_free", "name": "Fan Free", "role": "fan" },
    { "key": "band_free", "name": "Band Free", "role": "band" },
    { "key": "band_starter", "name": "Band Starter", "role": "band" },
    { "key": "blogger_pro", "name": "Blogger Pro", "role": "blogger" }
  ],
  "abilities": [
    {
      "ability": { "key": "create_recommendation", "name": "Create Recommendation", "category": "content" },
      "fan_free": true,
      "band_free": true,
      "band_starter": true,
      "blogger_pro": true
    },
    {
      "ability": { "key": "schedule_post", "name": "Schedule Posts", "category": "content" },
      "fan_free": false,
      "band_free": false,
      "band_starter": false,
      "blogger_pro": true
    }
  ]
}
```

---

### POST /admin/plans/:id/abilities/:ability_id

Add an ability to a plan (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "message": "Ability 'Schedule Posts' added to plan 'Blogger Pro'",
  "plan": { ... }
}
```

**Notes:**

- Changes take effect immediately for all users on this plan
- User ability caches are automatically cleared

---

### DELETE /admin/plans/:id/abilities/:ability_id

Remove an ability from a plan (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "message": "Ability 'Schedule Posts' removed from plan 'Blogger Pro'",
  "plan": { ... }
}
```

**Error Response (404 Not Found):**

```json
{
  "error": "Ability not found on this plan"
}
```

---

### GET /admin/abilities

Get all abilities, optionally grouped by category (admin only).

**Authentication:** Required (Admin only)

**Query Parameters:**

- `grouped` (optional): Set to "true" to group abilities by category

**Response (200 OK) - Default:**

```json
{
  "abilities": [
    {
      "id": 1,
      "key": "create_recommendation",
      "name": "Create Recommendation",
      "description": "Recommend songs to followers",
      "category": "content",
      "plans": [
        { "key": "fan_free", "name": "Fan Free" },
        { "key": "band_free", "name": "Band Free" }
      ],
      "created_at": "2026-02-23T00:00:00.000Z",
      "updated_at": "2026-02-23T00:00:00.000Z"
    }
  ]
}
```

**Response (200 OK) - Grouped (grouped=true):**

```json
{
  "abilities": {
    "content": [
      {
        "id": 1,
        "key": "create_recommendation",
        "name": "Create Recommendation",
        "description": "Recommend songs to followers",
        "category": "content",
        "plans": [...]
      }
    ],
    "monetization": [...],
    "audience": [...],
    "social": [...],
    "analytics": [...],
    "band": [...]
  }
}
```

---

### GET /admin/abilities/categories

Get list of valid ability categories (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "categories": ["content", "monetization", "audience", "social", "analytics", "band"]
}
```

---

### GET /admin/abilities/:id

Get a single ability with its plans (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "ability": {
    "id": 1,
    "key": "create_recommendation",
    "name": "Create Recommendation",
    "description": "Recommend songs to followers",
    "category": "content",
    "plans": [
      { "key": "fan_free", "name": "Fan Free" },
      { "key": "band_free", "name": "Band Free" }
    ],
    "created_at": "2026-02-23T00:00:00.000Z",
    "updated_at": "2026-02-23T00:00:00.000Z"
  }
}
```

---

### POST /admin/abilities

Create a new ability (admin only).

**Authentication:** Required (Admin only)

**Request Body:**

```json
{
  "key": "new_feature",
  "name": "New Feature",
  "description": "Description of the new feature",
  "category": "content"
}
```

**Required Fields:**

- `key` - Unique identifier (snake_case, e.g., `schedule_post`)
- `name` - Human-readable name
- `category` - Must be one of: `content`, `monetization`, `audience`, `social`, `analytics`, `band`

**Optional Fields:**

- `description` - Detailed description of what this ability enables

**Response (201 Created):**

```json
{
  "message": "Ability 'New Feature' created successfully",
  "ability": {
    "id": 27,
    "key": "new_feature",
    "name": "New Feature",
    "description": "Description of the new feature",
    "category": "content",
    "plans": [],
    "created_at": "2026-02-23T00:00:00.000Z",
    "updated_at": "2026-02-23T00:00:00.000Z"
  }
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "errors": ["Key has already been taken"]
}
```

---

### PATCH /admin/abilities/:id

Update an ability (admin only).

**Authentication:** Required (Admin only)

**Request Body:**

```json
{
  "name": "Updated Feature Name",
  "description": "Updated description",
  "category": "monetization"
}
```

All fields are optional. The `key` can be updated but must remain unique.

**Response (200 OK):**

```json
{
  "message": "Ability 'Updated Feature Name' updated successfully",
  "ability": { ... }
}
```

---

### DELETE /admin/abilities/:id

Delete an ability (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**

```json
{
  "message": "Ability 'Feature Name' deleted successfully"
}
```

**Error Response (422 Unprocessable Entity):**

If the ability is used by any plans, it cannot be deleted:

```json
{
  "error": "Cannot delete ability 'Create Recommendation' because it is used by: Fan Free, Band Free, Band Starter",
  "plans": [
    { "key": "fan_free", "name": "Fan Free" },
    { "key": "band_free", "name": "Band Free" },
    { "key": "band_starter", "name": "Band Starter" }
  ]
}
```

**Notes:**

- You must remove the ability from all plans before deleting it
- Use `DELETE /admin/plans/:id/abilities/:ability_id` to remove an ability from a plan

---

## Health Check Endpoints

### GET /health

Health check endpoint.

**Authentication:** None

**Response (200 OK):**

```
OK
```

---

### GET /up

Alternative health check endpoint.

**Authentication:** None

**Response (200 OK):**

```
OK
```

---

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Not authorized"
}
```

### 403 Forbidden

```json
{
  "error": "Admin access required"
}
```

or

```json
{
  "error": "You are not authorized to modify this resource"
}
```

or (for ability-gated endpoints):

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "schedule_post",
  "upgrade_plan": "blogger_pro"
}
```

### 404 Not Found

```json
{
  "error": "Record not found"
}
```

### 422 Unprocessable Entity

```json
{
  "errors": ["Username can't be blank", "Email has already been taken"]
}
```

---

## Data Types

### Account Types

- `fan` - Standard user account (identified by username)
- `band` - Band account (identified by primary band name)
- `music_blogger` - Music blogger account (publishing and audience tools)

### Roles

User identity type that determines the overall UI experience:
- `fan` - Discovers and recommends music
- `band` - Artist/band with business tools
- `blogger` - Music blogger with publishing tools

### Plans

Subscription tiers that grant abilities:
- `fan_free` - Free fan plan
- `band_free` - Free band plan
- `band_starter` - $15/month band plan with analytics, storefront, newsletter
- `band_pro` - $40/month band plan (all band features)
- `blogger` - $9/month blogger plan (basic publishing)
- `blogger_pro` - $18/month blogger plan (full features)

### Ability Categories

- `content` - Content creation (recommendations, blog posts, scheduling)
- `monetization` - Revenue features (storefront, donations, subscriptions)
- `audience` - Community features (following, comments, newsletters)
- `social` - Social integrations (Instagram, Threads, playlists)
- `analytics` - Analytics and insights
- `band` - Band-specific features (profile, music, events)

### Review Liked Aspects

Common values: `"melody"`, `"lyrics"`, `"production"`, `"vocals"`, `"instrumentation"`, `"energy"`, `"originality"`

---

## Notes

1. **Onboarding Flow:**
   - New users start with `role: null` and `onboarding_completed: false`
   - Step 1: POST `/onboarding/account-type` to choose FAN or BAND
   - Step 2: POST `/onboarding/complete-fan-profile` (for FAN) or `/onboarding/complete-band-profile` (for BAND)
   - After onboarding, users can access all authenticated endpoints

2. **BAND Accounts:**
   - Do not have usernames
   - Identified by their primary band name
   - `display_name` returns the primary band name

3. **Admin Users:**
   - Can modify or delete any resource
   - Identified by `admin: true` in profile response

4. **Disabled Users:**
   - Admins can disable users via `PATCH /admin/users/:id/toggle-disabled`
   - Admins can delete users via `DELETE /admin/users/:id`
   - Disabled users cannot login (returns "This account has been disabled")
   - Disabled user profiles return 404 on public profile pages (`/users/:username`)
   - Reviews from disabled users are hidden from all public feeds and band pages
   - Admins can still view disabled users and their reviews in the admin dashboard

5. **Disabled Bands:**
   - Admins can disable bands via `PATCH /admin/bands/:id/toggle-disabled`
   - Admins can delete bands via `DELETE /admin/bands/:id`
   - Disabled bands return 404 on public band pages (`/bands/:slug`)
   - Disabled bands are hidden from all public band listings
   - Admins can still view disabled bands in the admin dashboard

6. **File Uploads:**
   - Use `multipart/form-data` content type
   - Supported fields: `profile_image` (users), `profile_picture` (bands)

7. **Follow System:**
   - Users (both fans and bands) can follow other users (including themselves)
   - Following feed (`GET /feed/following`) returns a unified `feed_items` array of `{ type, data }` objects showing:
     - Your own reviews, posts, and events
     - Reviews, posts, and events from users you follow
     - Reviews written about bands owned by users you follow
   - Each feed item has a `type` field (`"review"`, `"post"`, or `"event"`) and a `data` field with the item details
   - Review and event author objects include `display_name`
   - Following feed is paginated for performance
   - Dashboard previews (`following_feed_preview`) use the same `{ type, data }` format
   - Public profiles include `followers_count` and `following_count`
   - When viewing a profile while authenticated, `following` boolean indicates if you follow that user

8. **Scrobbling:**
   - Scrobble endpoints use the `/api/v1` namespace
   - Batch submissions accept up to 50 scrobbles per request
   - Rate limited to 100 submissions per hour per user
   - `played_at` must be within the last 14 days and not in the future
   - `duration_ms` must be at least 30000 (30 seconds)
   - Duplicate scrobbles (same track/artist/played_at within 30 seconds) are silently skipped
   - After creation, scrobbles are asynchronously enriched with metadata (track, artist, album info)
   - The `metadata_status` field tracks enrichment: `pending`, `enriched`, `not_found`, `failed`
   - Uses cursor-based pagination (not page-based) via `next_cursor` and `has_more`

9. **Notifications:**
   - Users receive notifications when someone follows them
   - Band owners receive notifications when someone reviews their band
   - Review authors receive notifications when someone likes their review
   - Review authors receive notifications when someone comments on their review
   - Event creators receive notifications when someone likes their event
   - Event creators receive notifications when someone comments on their event
   - Event comment authors receive notifications when someone likes their comment
   - Notification types: `new_follower`, `new_review`, `review_like`, `review_comment`, `event_like`, `event_comment`, `event_comment_like`
   - Notifications are paginated and include unread count
   - Users can mark individual notifications or all notifications as read
   - Users do not receive notifications for their own actions (e.g., liking their own review)

10. **Review Likes:**
    - Users can like and unlike reviews
    - Each review displays `likes_count` (total number of likes) and `liked_by_current_user` (boolean)
    - Users can view a paginated list of all reviews they have liked via `GET /reviews/liked`
    - A user can only like a review once (duplicate likes return an error)

11. **Review Comments:**
    - Users can comment on reviews
    - Comments are limited to 300 characters
    - Each review displays `comments_count` (total number of comments)
    - Comments are returned in chronological order (oldest first)
    - Only the comment owner or an admin can edit/delete a comment

12. **Recently Played Aggregation:**
    - The `/recently-played` endpoint aggregates tracks from multiple sources
    - Currently supported sources: `lastfm` (Last.fm API), `scrobble` (local scrobbles from `/api/v1/scrobbles`)
    - Sources are fetched in parallel for optimal performance
    - Tracks are merged and sorted by `played_at` timestamp (most recent first)
    - Consecutive duplicate tracks (same name + artist within 5 minutes) are deduplicated
    - Use the `sources` query parameter to filter to specific sources
    - Designed to be extensible for future sources (e.g., Apple Music)

14. **Roles, Plans & Abilities (RBAC):**
    - Every user has a `role` (fan, band, blogger) that determines their identity
    - Every user has a `plan` that determines their subscription tier
    - Plans grant `abilities` (atomic permissions like `schedule_post`, `manage_storefront`)
    - User profile responses include `role`, `plan`, and `abilities` array
    - API endpoints can require specific abilities using `require_ability!`
    - When a user lacks a required ability, the API returns 403 with `error: "upgrade_required"`
    - The response includes `required_ability` and `upgrade_plan` for contextual upgrade prompts
    - Admins can manage plan-ability mappings via `/admin/plans` and `/admin/abilities` endpoints
    - See `docs/RBAC_SYSTEM.md` for full architecture documentation

13. **User Mentions (@tagging):**
    - Users can mention other users in reviews and comments using `@username` syntax
    - Mentioned users receive notifications when tagged
    - Maximum 10 mentions per post/comment
    - Self-mentions are silently ignored (no notification sent)
    - Invalid usernames return an error: "Looks like you tagged a user that doesn't exist: @username"
    - Disabled users cannot be mentioned
    - Reviews and comments include both raw text and formatted text with mention links:
      - `review_text` / `body`: Original text with `@username`
      - `formatted_review_text` / `formatted_body`: Text with `[@username](user:123)` format
      - `mentions`: Array of mentioned user details (user_id, username, display_name)
    - Frontend can parse the `[@text](user:id)` format with regex: `/\[@(\w+)\]\(user:(\d+)\)/g`
    - **Combined notifications**: If someone comments on your review AND mentions you in that comment, you receive a single combined notification (not two separate ones). The notification will have `mentioned: true` and the message will say "mentioned you in a comment on your review"

---
