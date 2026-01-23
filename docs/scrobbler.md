# Product Requirements Document: Scrobbling API

**Project:** GoodSongs Scrobbling Backend  
**Owner:** Angie  
**Last Updated:** January 2026  
**Status:** Draft

---

## Overview

This document defines the requirements for the Rails API endpoints that power GoodSongs' listening history feature. The API receives scrobble data from mobile clients, enriches it with metadata from MusicBrainz, and serves the data back for the recently played feed.

### Goals

- Accept and store listening data from mobile clients reliably
- Enrich sparse scrobble data with album art, artist images, and metadata from MusicBrainz
- Serve a performant recently played feed for users
- Provide foundation for future features: listening stats, artist analytics, recommendations

### Non-Goals (for this phase)

- Spotify/Apple Music OAuth integrations (future phase)
- Real-time websocket updates for the feed
- Social features like sharing or reactions to listens
- Detailed listening analytics dashboards

---

## User Stories

**As a mobile app user**, I want my listening history saved automatically so I can see what I've been playing and share my taste with others.

**As a user viewing my profile**, I want to see album artwork and artist info for my recent listens so the feed looks rich and engaging.

**As a user**, I want my recently played feed to load quickly even if I have thousands of scrobbles.

**As a band on GoodSongs**, I want to eventually see when fans are listening to my music (future phase, but architecture should support).

---

## Data Model

### Scrobble

| Field                    | Type     | Description                                          |
| ------------------------ | -------- | ---------------------------------------------------- |
| id                       | uuid     | Primary key                                          |
| user_id                  | uuid     | Foreign key to users table                           |
| track_id                 | uuid     | Foreign key to tracks table (nullable until matched) |
| track_name               | string   | Track title as reported by client                    |
| artist_name              | string   | Artist name as reported by client                    |
| album_name               | string   | Album name as reported by client (nullable)          |
| duration_ms              | integer  | Track duration in milliseconds                       |
| played_at                | datetime | When the track was played (from client)              |
| source_app               | string   | Source application (spotify, youtube_music, etc.)    |
| source_device            | string   | Device identifier or type                            |
| musicbrainz_recording_id | string   | MusicBrainz recording MBID (nullable)                |
| metadata_status          | enum     | pending, enriched, not_found, failed                 |
| created_at               | datetime | When scrobble was received                           |

### Track (canonical track data)

| Field                    | Type     | Description                                      |
| ------------------------ | -------- | ------------------------------------------------ |
| id                       | uuid     | Primary key                                      |
| name                     | string   | Canonical track name                             |
| artist_id                | uuid     | Foreign key to artists table                     |
| album_id                 | uuid     | Foreign key to albums table (nullable)           |
| duration_ms              | integer  | Track duration                                   |
| musicbrainz_recording_id | string   | MusicBrainz recording MBID                       |
| isrc                     | string   | International Standard Recording Code (nullable) |
| created_at               | datetime |                                                  |
| updated_at               | datetime |                                                  |

### Artist

| Field                 | Type     | Description                                           |
| --------------------- | -------- | ----------------------------------------------------- |
| id                    | uuid     | Primary key                                           |
| name                  | string   | Artist name                                           |
| musicbrainz_artist_id | string   | MusicBrainz artist MBID                               |
| image_url             | string   | Artist image URL (from MusicBrainz/Cover Art Archive) |
| bio                   | text     | Artist biography (nullable)                           |
| created_at            | datetime |                                                       |
| updated_at            | datetime |                                                       |

### Album

| Field                  | Type     | Description                            |
| ---------------------- | -------- | -------------------------------------- |
| id                     | uuid     | Primary key                            |
| name                   | string   | Album name                             |
| artist_id              | uuid     | Foreign key to artists table           |
| musicbrainz_release_id | string   | MusicBrainz release MBID               |
| cover_art_url          | string   | Album cover URL from Cover Art Archive |
| release_date           | date     | Album release date (nullable)          |
| created_at             | datetime |                                        |
| updated_at             | datetime |                                        |

---

## API Endpoints

### Authentication

All endpoints require authentication via Bearer token in the Authorization header. The mobile app obtains tokens through the existing auth flow.

```
Authorization: Bearer <jwt_token>
```

---

### POST /api/v1/scrobbles

Submit one or more scrobbles. Supports batching for offline sync scenarios.

**Request Body:**

```json
{
  "scrobbles": [
    {
      "track_name": "Mayonaise",
      "artist_name": "The Smashing Pumpkins",
      "album_name": "Siamese Dream",
      "duration_ms": 345000,
      "played_at": "2026-01-15T14:32:00Z",
      "source_app": "spotify",
      "source_device": "android_pixel_8"
    }
  ]
}
```

**Validation Rules:**

- track_name: required, string, max 500 chars
- artist_name: required, string, max 500 chars
- album_name: optional, string, max 500 chars
- duration_ms: required, integer, min 30000 (30 seconds minimum to count as a listen)
- played_at: required, ISO 8601 datetime, must not be in the future, must be within last 14 days
- source_app: required, string, max 100 chars
- source_device: optional, string, max 100 chars
- Maximum 50 scrobbles per request

**Duplicate Handling:**

A scrobble is considered duplicate if the same user has a scrobble with matching track_name, artist_name, and played_at within a 30-second window. Duplicates are silently ignored (not an error).

**Response (201 Created):**

```json
{
  "data": {
    "accepted": 3,
    "rejected": 0,
    "scrobbles": [
      {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "track_name": "Mayonaise",
        "artist_name": "The Smashing Pumpkins",
        "album_name": "Siamese Dream",
        "played_at": "2026-01-15T14:32:00Z",
        "metadata_status": "pending"
      }
    ]
  }
}
```

**Response (422 Unprocessable Entity):**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "One or more scrobbles failed validation",
    "details": [
      {
        "index": 0,
        "field": "duration_ms",
        "message": "must be at least 30000"
      }
    ]
  }
}
```

**Background Processing:**

After successful submission, enqueue a job to enrich each scrobble with MusicBrainz metadata (see MusicBrainz Integration section).

---

### GET /api/v1/scrobbles

Retrieve the authenticated user's scrobble history.

**Query Parameters:**

| Param  | Type     | Default | Description                                    |
| ------ | -------- | ------- | ---------------------------------------------- |
| limit  | integer  | 20      | Results per page (max 100)                     |
| cursor | string   | null    | Cursor for pagination (played_at of last item) |
| since  | datetime | null    | Only scrobbles after this time                 |
| until  | datetime | null    | Only scrobbles before this time                |

**Response (200 OK):**

```json
{
  "data": {
    "scrobbles": [
      {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "track_name": "Mayonaise",
        "artist_name": "The Smashing Pumpkins",
        "album_name": "Siamese Dream",
        "played_at": "2026-01-15T14:32:00Z",
        "source_app": "spotify",
        "track": {
          "id": "track-uuid",
          "name": "Mayonaise",
          "duration_ms": 345000,
          "artist": {
            "id": "artist-uuid",
            "name": "The Smashing Pumpkins",
            "image_url": "https://..."
          },
          "album": {
            "id": "album-uuid",
            "name": "Siamese Dream",
            "cover_art_url": "https://coverartarchive.org/..."
          }
        }
      }
    ],
    "pagination": {
      "next_cursor": "2026-01-15T14:00:00Z",
      "has_more": true
    }
  }
}
```

**Notes:**

- Results ordered by played_at descending (most recent first)
- Cursor-based pagination for stable results during infinite scroll
- The nested track/artist/album objects may be null if metadata enrichment is still pending or failed

---

### GET /api/v1/scrobbles/recent

Convenience endpoint for the "recently played" feed, optimized for the common case.

**Query Parameters:**

| Param | Type    | Default | Description                |
| ----- | ------- | ------- | -------------------------- |
| limit | integer | 20      | Results to return (max 50) |

**Response:** Same structure as GET /api/v1/scrobbles but without pagination params. Returns most recent scrobbles only.

---

### GET /api/v1/users/:user_id/scrobbles

Retrieve another user's public scrobble history (for profile pages).

**Query Parameters:** Same as GET /api/v1/scrobbles

**Authorization:** Only returns data if the target user has public listening history enabled in their privacy settings.

**Response:** Same structure as GET /api/v1/scrobbles

---

### DELETE /api/v1/scrobbles/:id

Delete a specific scrobble from the user's history.

**Response (204 No Content):** Success, no body

**Response (404 Not Found):** Scrobble doesn't exist or belongs to another user

---

## MusicBrainz Integration

### Overview

MusicBrainz is an open music encyclopedia that provides metadata including artist info, album details, and relationships to cover art. The Cover Art Archive (hosted by Internet Archive) provides album artwork linked to MusicBrainz releases.

### Rate Limiting

MusicBrainz requires a maximum of 1 request per second per application. Implement a rate limiter for all outgoing requests.

### Enrichment Flow

1. Scrobble is created with metadata_status: pending
2. Background job (Sidekiq) picks up pending scrobbles
3. Search MusicBrainz for matching recording
4. If found, fetch/create canonical Track, Artist, Album records
5. Fetch cover art from Cover Art Archive
6. Update scrobble with track_id and metadata_status: enriched
7. If not found after reasonable attempt, set metadata_status: not_found

### MusicBrainz API Calls

**Search for Recording:**

```
GET https://musicbrainz.org/ws/2/recording
  ?query=recording:"Mayonaise" AND artist:"Smashing Pumpkins"
  &fmt=json
  &limit=5
```

**Get Recording Details:**

```
GET https://musicbrainz.org/ws/2/recording/{mbid}
  ?inc=artists+releases+isrcs
  &fmt=json
```

**Get Release (Album) Details:**

```
GET https://musicbrainz.org/ws/2/release/{mbid}
  ?inc=artists+recordings
  &fmt=json
```

### Cover Art Archive

**Get Cover Art:**

```
GET https://coverartarchive.org/release/{release_mbid}/front-500
```

Returns 307 redirect to actual image URL. Cache the final URL.

**Fallback sizes:** front-250, front-500, front-1200, or just /front for original

### Caching Strategy

- Cache Artist records indefinitely (update on access if stale > 30 days)
- Cache Album/Track records indefinitely (update on access if stale > 30 days)
- Store cover art URLs directly (they're stable)
- For unmatched scrobbles, retry enrichment once per day for 7 days, then mark as permanently not_found

### Required Headers

All MusicBrainz requests must include a User-Agent identifying the application:

```
User-Agent: GoodSongs/1.0.0 (https://goodsongs.app; api@goodsongs.app)
```

---

## Background Jobs

### ScrobbleEnrichmentJob

- Triggered after scrobble creation
- Attempts MusicBrainz lookup and enrichment
- Implements exponential backoff on rate limit errors
- Max 3 retries, then marks as failed

### MetadataRefreshJob

- Scheduled daily
- Re-attempts enrichment for not_found scrobbles less than 7 days old
- Refreshes stale artist/album metadata (> 30 days since last update)

---

## Performance Requirements

- POST /scrobbles: < 200ms p95 response time
- GET /scrobbles: < 100ms p95 for first page
- GET /scrobbles/recent: < 50ms p95 (heavily cached)
- Background enrichment: process within 5 minutes of scrobble submission

### Indexing

Ensure database indexes on:

- scrobbles: (user_id, played_at DESC)
- scrobbles: (metadata_status, created_at) for background job queries
- tracks: (musicbrainz_recording_id)
- artists: (musicbrainz_artist_id)
- albums: (musicbrainz_release_id)

### Caching

- Cache GET /scrobbles/recent per user with 60-second TTL
- Invalidate on new scrobble submission
- Cache MusicBrainz/Cover Art responses for 24 hours minimum

---

## Error Handling

All error responses follow this format:

```json
{
  "error": {
    "code": "error_code",
    "message": "Human readable message",
    "details": {}
  }
}
```

**Error Codes:**

| Code              | HTTP Status | Description                    |
| ----------------- | ----------- | ------------------------------ |
| unauthorized      | 401         | Missing or invalid auth token  |
| forbidden         | 403         | User doesn't have permission   |
| not_found         | 404         | Resource doesn't exist         |
| validation_failed | 422         | Request body failed validation |
| rate_limited      | 429         | Too many requests              |
| internal_error    | 500         | Unexpected server error        |

---

## Security Considerations

- Validate all input lengths to prevent storage abuse
- Rate limit scrobble submissions per user (max 100/hour reasonable for heavy listening)
- Sanitize track/artist/album names before MusicBrainz queries
- Don't expose internal IDs in error messages
- Log scrobble submissions for abuse detection

---

## Testing Requirements

### Unit Tests

- Scrobble model validations
- Duplicate detection logic
- MusicBrainz query building
- Response serializers

### Integration Tests

- Full scrobble submission flow
- Pagination behavior
- MusicBrainz enrichment with mocked responses
- Error handling paths

### Load Tests

- Simulate 100 concurrent users submitting scrobbles
- Verify background job queue doesn't back up under load

---

## Open Questions

1. Should we store raw source data (like Spotify track IDs) for potential future integrations?
2. What's the retention policy for scrobbles? Keep forever or archive after N years?
3. Should we support "private" scrobbles that don't appear in public feeds?

---

## Milestones

**Phase 1: Core API (Target: 2 weeks)**

- [x] POST /scrobbles endpoint with validation
- [x] GET /scrobbles and /scrobbles/recent
- [x] Basic database schema
- [x] Authentication integration

**Phase 2: MusicBrainz Integration (Target: 2 weeks)**

- [x] MusicBrainz client with rate limiting
- [x] Cover Art Archive integration
- [x] Background enrichment jobs
- [x] Canonical track/artist/album records

**Phase 3: Polish (Target: 1 week)**

- [x] Caching layer
- [x] Performance optimization
- [x] Comprehensive error handling
- [x] Documentation
