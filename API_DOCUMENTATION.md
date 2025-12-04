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

## Onboarding Endpoints

### GET /onboarding/status

Get current onboarding status for authenticated user.

**Authentication:** Required (onboarding check skipped)

**Response (200 OK):**
```json
{
  "onboarding_completed": false,
  "account_type": null
}
```

For BAND accounts with primary band:
```json
{
  "onboarding_completed": true,
  "account_type": "band",
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
  "account_type": "fan"
}
```
or
```json
{
  "account_type": "band"
}
```

**Response (200 OK):**
```json
{
  "message": "Account type set successfully",
  "account_type": "fan",
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
    "spotify_connected": false,
    "profile_image_url": "https://...",
    "account_type": "fan",
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
    "spotify_connected": false,
    "profile_image_url": null,
    "account_type": "band",
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
  "spotify_connected": true,
  "profile_image_url": "https://...",
  "account_type": "fan",
  "onboarding_completed": true,
  "display_name": "johndoe",
  "admin": false,
  "city": "Los Angeles",
  "region": "California",
  "location": "Los Angeles, California",
  "latitude": 34.0522,
  "longitude": -118.2437
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
  "spotify_connected": false,
  "profile_image_url": null,
  "account_type": "band",
  "onboarding_completed": true,
  "display_name": "The Band Name",
  "admin": false,
  "city": null,
  "region": null,
  "location": null,
  "latitude": null,
  "longitude": null,
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
```

Note: When city/region are provided, latitude and longitude are automatically calculated via geocoding. The `region` field can be used for US states (e.g., "California"), countries (e.g., "United Kingdom"), or provinces (e.g., "Ontario, Canada").

**Response (200 OK):**
Returns updated user profile (same format as GET /profile)

---

### POST /update-profile

Alias for PATCH /profile (for frontend compatibility).

---

### GET /users/:username

Get public profile for a user by username.

**Authentication:** None

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
  "account_type": "fan",
  "display_name": "johndoe",
  "location": "Los Angeles, California",
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
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
    }
  ],
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
  ]
}
```

---

### GET /recently-played

Get user's recently played tracks from Spotify.

**Authentication:** Required (Spotify must be connected)

**Query Parameters:**
- `limit` (optional): Number of tracks to return (default: 20)

**Response (200 OK):**
```json
{
  "items": [
    {
      "track": {
        "name": "Song Name",
        "artists": [{ "name": "Artist Name" }],
        "album": {
          "name": "Album Name",
          "images": [{ "url": "https://..." }]
        },
        "external_urls": { "spotify": "https://open.spotify.com/track/..." }
      },
      "played_at": "2024-12-01T00:00:00.000Z"
    }
  ]
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "Spotify not connected"
}
```

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
    "created_at": "2024-12-01T00:00:00.000Z",
    "updated_at": "2024-12-01T00:00:00.000Z"
  }
]
```

---

### GET /reviews/:id

Get a single review by ID.

**Authentication:** Required

**Response (200 OK):**
Returns single review object (same format as items in GET /reviews)

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
    "liked_aspects": ["melody", "lyrics", "production"]
  }
}
```

**Response (201 Created):**
Returns created review object

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
    "about": "We make great music",
    "profile_picture_url": "https://...",
    "reviews_count": 5,
    "user_owned": true,
    "owner": { "id": 1, "username": "johndoe" },
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
```

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

## Admin Endpoints

### GET /admin/users

Get all users (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "username": "johndoe",
    "email": "user@example.com",
    "about_me": "Music lover",
    "profile_image_url": "https://...",
    "reviews_count": 10,
    "bands_count": 2,
    "account_type": "fan",
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
    "account_type": "band",
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
]
```

**Error Response (403 Forbidden):**
```json
{
  "error": "Admin access required"
}
```

---

### GET /admin/users/:id

Get a single user's profile and all their reviews (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**
```json
{
  "user": {
    "id": 1,
    "username": "johndoe",
    "email": "user@example.com",
    "about_me": "Music lover",
    "profile_image_url": "https://...",
    "reviews_count": 10,
    "bands_count": 2,
    "account_type": "fan",
    "onboarding_completed": true,
    "display_name": "johndoe",
    "admin": false,
    "disabled": false
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
      "created_at": "2024-12-01T00:00:00.000Z",
      "updated_at": "2024-12-01T00:00:00.000Z"
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
    "account_type": "fan",
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

## Spotify Integration Endpoints

### GET /spotify/connect

Initiate Spotify OAuth flow.

**Authentication:** Required (or via auth_code parameter)

**Query Parameters:**
- `auth_code` (optional): Temporary auth code for browser-based flow

**Response:**
- For JSON requests: `{ "auth_url": "https://accounts.spotify.com/authorize?..." }`
- For browser requests: Redirects to Spotify authorization page

---

### GET /auth/spotify/callback

Spotify OAuth callback (called by Spotify after authorization).

**Authentication:** None (uses state parameter)

**Query Parameters:**
- `code`: Authorization code from Spotify
- `state`: User ID for verification
- `error` (optional): Error message if authorization failed

**Response:**
Redirects to `{FRONTEND_URL}/dashboard?spotify=connected`

---

### DELETE /spotify/disconnect

Disconnect Spotify account.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Spotify account disconnected successfully"
}
```

---

### GET /spotify/status

Check Spotify connection status.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "connected": true,
  "expires_at": "2024-12-01T01:00:00.000Z"
}
```

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

### Review Liked Aspects
Common values: `"melody"`, `"lyrics"`, `"production"`, `"vocals"`, `"instrumentation"`, `"energy"`, `"originality"`

---

## Notes

1. **Onboarding Flow:**
   - New users start with `account_type: null` and `onboarding_completed: false`
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
   - Disabled users cannot login (returns "This account has been disabled")
   - Disabled user profiles return 404 on public profile pages (`/users/:username`)
   - Reviews from disabled users are hidden from all public feeds and band pages
   - Admins can still view disabled users and their reviews in the admin dashboard

5. **File Uploads:**
   - Use `multipart/form-data` content type
   - Supported fields: `profile_image` (users), `profile_picture` (bands)
