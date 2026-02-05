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
    "lastfm_connected": false,
    "lastfm_username": null,
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
    "lastfm_connected": false,
    "lastfm_username": null,
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
  "account_type": "fan",
  "onboarding_completed": true,
  "display_name": "johndoe",
  "admin": false,
  "city": "Los Angeles",
  "region": "California",
  "location": "Los Angeles, California",
  "latitude": 34.0522,
  "longitude": -118.2437,
  "followers_count": 25,
  "following_count": 12
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
  "account_type": "band",
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

**Authentication:** None (optional - if authenticated, includes `following` field)

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
  "followers_count": 25,
  "following_count": 12,
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

Note: The `following` field is only included if the request includes a valid authentication token.

---

### GET /recently-played

Get user's recently played tracks from Last.fm.

**Authentication:** Required (Last.fm must be connected)

**Query Parameters:**
- `limit` (optional): Number of tracks to return (default: 20)

**Response (200 OK):**
```json
{
  "tracks": [
    {
      "name": "Song Name",
      "mbid": "musicbrainz-track-id",
      "artists": [
        {
          "name": "Artist Name",
          "mbid": "musicbrainz-artist-id",
          "lastfm_url": "https://www.last.fm/music/Artist+Name"
        }
      ],
      "album": {
        "name": "Album Name",
        "mbid": "musicbrainz-album-id",
        "images": [
          { "url": "https://...", "size": "small" },
          { "url": "https://...", "size": "medium" },
          { "url": "https://...", "size": "large" },
          { "url": "https://...", "size": "extralarge" }
        ]
      },
      "lastfm_url": "https://www.last.fm/music/Artist+Name/_/Song+Name",
      "played_at": "2024-12-01T00:00:00Z",
      "now_playing": false,
      "loved": true
    }
  ]
}
```

Note: If the track is currently playing, `now_playing` will be `true` and `played_at` will be `null`.

**Error Response (400 Bad Request):**
```json
{
  "error": "No Last.fm username connected"
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
    "likes_count": 5,
    "liked_by_current_user": false,
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
    "liked_aspects": ["melody", "lyrics", "production"],
    "band_musicbrainz_id": "a74b1b7f-71a5-4011-9441-d0b5e4122711",
    "band_lastfm_artist_name": "Artist Name"
  }
}
```

Note: `band_musicbrainz_id` and `band_lastfm_artist_name` are optional. When provided, they are saved to the band record and used to automatically fetch artist images from MusicBrainz/Wikidata.

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

### GET /feed/following

Get paginated feed of reviews from users you follow and reviews about bands owned by users you follow.

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
        "username": "followeduser",
        "profile_image_url": "https://..."
      },
      "likes_count": 3,
      "liked_by_current_user": true,
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

## Event Endpoints

### GET /bands/:slug/events

Get upcoming events for a band.

**Authentication:** None

**Response (200 OK):**
```json
[
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
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
]
```

---

### POST /bands/:slug/events

Create a new event for a band.

**Authentication:** Required (band owner only)

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
    "ticket_link": "https://tickets.example.com/event/123",
    "price": "$25",
    "age_restriction": "21+",
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
Returns created event object (same format as GET /bands/:slug/events items)

---

### GET /events/:id

Get a single event by ID.

**Authentication:** None

**Response (200 OK):**
Returns event object (same format as GET /bands/:slug/events items)

---

### PATCH /events/:id

Update an event.

**Authentication:** Required (band owner only)

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

---

### DELETE /events/:id

Delete an event.

**Authentication:** Required (band owner only)

**Response (204 No Content)**

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
    "account_type": "fan",
    "profile_image_url": "https://...",
    "location": "Los Angeles, California",
    "following": true
  },
  {
    "id": 3,
    "username": null,
    "display_name": "The Band Name",
    "account_type": "band",
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
      "account_type": "fan",
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
    "account_type": "fan",
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
  "account_type": "fan",
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
- `account_type` - "fan" or "band"
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
    "account_type": "fan",
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
      "source_app": "goodsongs-ios",
      "source_device": "iPhone 15"
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
        "metadata_status": "pending"
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
        "errors": [
          { "field": "track_name", "message": "can't be blank" }
        ]
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
          }
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

Note: The `track` field is `null` when metadata enrichment has not yet completed.

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
   - Following feed (`GET /feed/following`) shows:
     - Reviews written by users you follow
     - Reviews written about bands owned by users you follow
   - Following feed is paginated for performance
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
   - Notification types: `new_follower`, `new_review`
   - Notifications are paginated and include unread count
   - Users can mark individual notifications or all notifications as read

10. **Review Likes:**
    - Users can like and unlike reviews
    - Each review displays `likes_count` (total number of likes) and `liked_by_current_user` (boolean)
    - Users can view a paginated list of all reviews they have liked via `GET /reviews/liked`
    - A user can only like a review once (duplicate likes return an error)
