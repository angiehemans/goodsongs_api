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

Get all bands including disabled ones (admin only).

**Authentication:** Required (Admin only)

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
    "updated_at": "2024-12-01T00:00:00.000Z",
    "disabled": false
  }
]
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

Get all reviews (admin only).

**Authentication:** Required (Admin only)

**Response (200 OK):**
Returns array of reviews (same format as GET /reviews)

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

8. **Notifications:**
   - Users receive notifications when someone follows them
   - Band owners receive notifications when someone reviews their band
   - Notification types: `new_follower`, `new_review`
   - Notifications are paginated and include unread count
   - Users can mark individual notifications or all notifications as read
