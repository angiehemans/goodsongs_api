# Spotify to Last.fm API Migration Plan

## Overview

This document outlines the plan to migrate from the Spotify API to the Last.fm API for fetching music data in the GoodSongs application.

---

## Current Spotify Implementation Summary

### Services
| File | Purpose |
|------|---------|
| `app/services/spotify_service.rb` | User-authenticated API calls (recently played, profile) |
| `app/services/spotify_artist_service.rb` | Public artist data (images) using client credentials |
| `app/services/spotify_url_service.rb` | OAuth authorization URL generation |

### Controllers
| File | Endpoints |
|------|-----------|
| `app/controllers/spotify_controller.rb` | OAuth flow (`/spotify/connect`, `/auth/spotify/callback`, etc.) |
| `app/controllers/users_controller.rb` | `GET /recently-played` endpoint |

### Background Jobs
| File | Purpose |
|------|---------|
| `app/jobs/fetch_spotify_image_job.rb` | Async fetching of artist images when band Spotify link is added |

### Database Columns
| Table | Columns |
|-------|---------|
| `users` | `spotify_access_token`, `spotify_refresh_token`, `spotify_expires_at` |
| `bands` | `spotify_link`, `spotify_image_url` |

### Data Currently Fetched from Spotify
- **Recently Played Tracks**: track name, ID, duration, preview URL, artists, album info, images, played_at timestamp
- **Artist Images**: High-quality artist photos (up to 640x640)
- **User Profile**: Authenticated user info

---

## Last.fm API Capabilities

### Authentication
- **API Key authentication** (no OAuth needed for read operations)
- **Session-based auth** for write operations (scrobbling)
- User data accessed via Last.fm username (not OAuth tokens)

### Key Methods
| Method | Purpose |
|--------|---------|
| `user.getRecentTracks` | Get user's recently scrobbled tracks |
| `user.getInfo` | Get user profile information |
| `artist.getInfo` | Get artist metadata including images |
| `artist.search` | Search for artists by name |
| `track.getInfo` | Get track metadata |

### Data Available from Last.fm
- Track name, artist, album, images
- Scrobble timestamps
- Artist images (multiple sizes: small, medium, large, extralarge, mega)
- Artist biography, tags, similar artists
- Listener/playcount statistics
- MusicBrainz IDs for cross-referencing

---

## Data Gaps & Differences

### 1. Streaming Links
| Spotify | Last.fm | Solution |
|---------|---------|----------|
| Preview URLs from API | Not available | Optional user-provided streaming link |

**Approach**: Users can optionally add a streaming link (Spotify, Apple Music, YouTube, etc.) when creating content. This is not required and will not be fetched from the API.

### 2. Different User Model (Simpler)
| Spotify | Last.fm |
|---------|---------|
| OAuth tokens stored per user | Last.fm username stored per user |
| Token refresh flow | No token refresh needed |

**Impact**: Users will need to connect their Last.fm account differently (provide username or authenticate via Last.fm).

### 3. Link Format Changes
| Spotify | Last.fm |
|---------|---------|
| `https://open.spotify.com/artist/{id}` | `https://www.last.fm/music/{artist_name}` |

**Impact**: Band `spotify_link` column needs to become `lastfm_link` or `lastfm_artist_name`. URL validation regex needs updating.

### 4. Image Quality/Availability
| Spotify | Last.fm |
|---------|---------|
| Consistent high-quality images | Varies by artist; some may have no images |

**Impact**: Need fallback handling for artists without images.

### 5. "Now Playing" vs "Recently Played"
| Spotify | Last.fm |
|---------|---------|
| What user is currently playing | What user has scrobbled (may have delay) |

**Impact**: Slight semantic difference; Last.fm depends on scrobbling which may not capture all listening.

---

## Migration Tasks

### Phase 1: Create Last.fm Services

- [ ] **Create `app/services/lastfm_service.rb`**
  - API key authentication setup
  - Method: `recently_played(username, limit: 20)` using `user.getRecentTracks`
  - Method: `user_profile(username)` using `user.getInfo`
  - Error handling for rate limits and invalid usernames
  - Response formatting to match current Spotify response structure

- [ ] **Create `app/services/lastfm_artist_service.rb`**
  - Method: `fetch_artist_image(artist_name_or_url)` using `artist.getInfo`
  - Method: `search_artist(query)` using `artist.search`
  - Image size selection (prefer extralarge or mega)
  - Handle artists with no images gracefully

### Phase 2: Update Database Schema

- [ ] **Create migration for users table**
  - Add `lastfm_username` column
  - Add `lastfm_session_key` (if we need authenticated features later)
  - Consider keeping Spotify columns during transition or removing them

- [ ] **Create migration for bands table**
  - Add `lastfm_artist_name` column
  - Rename `spotify_image_url` to `artist_image_url` (or add `lastfm_image_url`)
  - Consider deprecating `spotify_link` or renaming

### Phase 3: Update Controllers

- [ ] **Create `app/controllers/lastfm_controller.rb`**
  - `POST /lastfm/connect` - Store user's Last.fm username
  - `GET /lastfm/status` - Return connection status
  - `DELETE /lastfm/disconnect` - Remove Last.fm username

- [ ] **Update `app/controllers/users_controller.rb`**
  - Modify `recently_played` action to use LastfmService
  - Update response format if needed

- [ ] **Remove/deprecate `app/controllers/spotify_controller.rb`**

### Phase 4: Update Background Jobs

- [ ] **Rename/rewrite `fetch_spotify_image_job.rb`**
  - Create `app/jobs/fetch_artist_image_job.rb`
  - Use LastfmArtistService instead
  - Update trigger in Band model

### Phase 5: Update Models

- [ ] **Update `app/models/band.rb`**
  - Change URL validation from Spotify to Last.fm format (or allow artist name)
  - Update `after_commit` callback to use new job
  - Add method `lastfm_url` if storing artist name

- [ ] **Update `app/models/user.rb`**
  - Add `lastfm_username` accessor
  - Add method `lastfm_connected?`
  - Deprecate Spotify token methods

### Phase 6: Update Serializers

- [ ] **Update `app/serializers/user_serializer.rb`**
  - Change `spotify_connected` to `lastfm_connected`
  - Add `lastfm_username` to profile

- [ ] **Update `app/serializers/band_serializer.rb`**
  - Update `band_image_url` method to use new column name
  - Add/update link serialization

### Phase 7: Configuration & Cleanup

- [ ] **Update environment variables**
  - Add `LASTFM_API_KEY`
  - Add `LASTFM_SHARED_SECRET` (if using authenticated sessions)
  - Remove or deprecate Spotify credentials

- [ ] **Update Gemfile**
  - Remove `omniauth-spotify` gem
  - Optionally add a Last.fm client gem (or use HTTParty directly)

- [ ] **Update routes**
  - Add Last.fm routes
  - Deprecate/remove Spotify routes

- [ ] **Remove deprecated code**
  - `app/services/spotify_service.rb`
  - `app/services/spotify_artist_service.rb`
  - `app/services/spotify_url_service.rb`
  - `app/controllers/spotify_controller.rb`
  - `app/jobs/fetch_spotify_image_job.rb`
  - `config/initializers/omniauth.rb` (Spotify config)

---

## API Response Format Changes

### Recently Played - Current (Spotify)
```json
{
  "tracks": [
    {
      "id": "spotify_track_id",
      "name": "Track Name",
      "duration_ms": 240000,
      "preview_url": "https://...",
      "artists": [
        {
          "name": "Artist Name",
          "spotify_url": "https://open.spotify.com/artist/..."
        }
      ],
      "album": {
        "name": "Album Name",
        "images": [...]
      },
      "external_urls": {...},
      "played_at": "2025-01-17T..."
    }
  ]
}
```

### Recently Played - Proposed (Last.fm)
```json
{
  "tracks": [
    {
      "name": "Track Name",
      "mbid": "musicbrainz-id",
      "artists": [
        {
          "name": "Artist Name",
          "lastfm_url": "https://www.last.fm/music/Artist+Name"
        }
      ],
      "album": {
        "name": "Album Name",
        "images": [...]
      },
      "lastfm_url": "https://www.last.fm/music/Artist/_/Track",
      "played_at": "2025-01-17T...",
      "now_playing": false
    }
  ]
}
```

**Removed fields**: `id` (Spotify ID), `duration_ms`, `preview_url` (not needed)
**Added fields**: `mbid`, `lastfm_url`, `now_playing`

**Note**: Streaming links (Spotify, Apple Music, YouTube, etc.) can be optionally added by users when creating reviews or other content, but are not fetched from the API.

---

## Testing Requirements

- [ ] Unit tests for LastfmService
- [ ] Unit tests for LastfmArtistService
- [ ] Integration tests for new controller endpoints
- [ ] Test error handling (invalid username, rate limits, missing images)
- [ ] Test migration path for existing users with Spotify connections
- [ ] Verify frontend compatibility with new response format

---

## Frontend Considerations

The frontend will need updates to handle:

1. **New connection flow** - Username input instead of OAuth redirect
2. **Optional streaming links** - Add UI for users to optionally provide streaming links (Spotify, Apple Music, YouTube, etc.)
3. **Updated link formats** - Last.fm URLs instead of Spotify URLs
4. **New response format** - Adapt to changed field names (remove `duration_ms`, `preview_url`; add `now_playing`)

---

## Rollout Strategy

### Option A: Big Bang Migration
- Remove Spotify, add Last.fm in single release
- Simpler code, but disruptive to users

### Option B: Gradual Migration (Recommended)
1. Add Last.fm support alongside Spotify
2. Allow users to connect Last.fm accounts
3. Migrate features one at a time
4. Deprecate Spotify with warning period
5. Remove Spotify after migration period

---

## Environment Variables Required

```env
# Last.fm API
LASTFM_API_KEY=your_api_key_here
LASTFM_SHARED_SECRET=your_shared_secret_here  # Only if using authenticated sessions

# Remove these after migration
# SPOTIFY_CLIENT_ID=...
# SPOTIFY_CLIENT_SECRET=...
# SPOTIFY_REDIRECT_URI=...
```

---

## References

- [Last.fm API Documentation](https://www.last.fm/api)
- [Unofficial Last.fm API Docs](https://lastfm-docs.github.io/api-docs/)
- [user.getRecentTracks](https://lastfm-docs.github.io/api-docs/user/getRecentTracks/)
- [artist.getInfo](https://lastfm-docs.github.io/api-docs/artist/getInfo/)
