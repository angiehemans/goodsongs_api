# Scrobble Enrichment Service

This document describes how the scrobble enrichment system works in GoodSongs. When a user submits a scrobble (a record of a played track), the system automatically enriches it with metadata from MusicBrainz (primary) and Discogs (fallback).

## Overview

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────────┐
│  POST /scrobble │────▶│  Scrobble Created   │────▶│ ScrobbleEnrichmentJob│
│   (User App)    │     │  (status: pending)  │     │   (Background Job)   │
└─────────────────┘     └─────────────────────┘     └──────────┬───────────┘
                                                               │
                        ┌──────────────────────────────────────┘
                        ▼
         ┌──────────────────────────────┐
         │  ScrobbleEnrichmentService   │
         └──────────────┬───────────────┘
                        │
                        ▼
              ┌───────────────────┐
              │ Try MusicBrainz   │
              │   (primary)       │
              └────────┬──────────┘
                       │
           ┌───────────┴───────────┐
           │ Found?                │
           │                       │
      ┌────▼────┐            ┌─────▼─────┐
      │   Yes   │            │    No     │
      └────┬────┘            └─────┬─────┘
           │                       │
           ▼                       ▼
┌────────────────────┐   ┌───────────────────┐
│ Enrich from MB     │   │ Try Discogs       │
│ + Cover Art Archive│   │ (fallback)        │
│ + Fanart.tv        │   └────────┬──────────┘
└─────────┬──────────┘            │
          │              ┌────────┴────────┐
          │              │ Found?          │
          │              │                 │
          │         ┌────▼────┐      ┌─────▼─────┐
          │         │   Yes   │      │    No     │
          │         └────┬────┘      └─────┬─────┘
          │              │                 │
          │              ▼                 ▼
          │    ┌───────────────┐   ┌────────────────┐
          │    │ Enrich from   │   │ Mark as        │
          │    │ Discogs       │   │ not_found      │
          │    └───────┬───────┘   └────────────────┘
          │            │
          └─────┬──────┘
                ▼
  ┌──────────────────────────────┐
  │   Create/Update Records:     │
  │   - Band                     │
  │   - Album                    │
  │   - Track                    │
  │   - Link Scrobble → Track    │
  └──────────────────────────────┘
```

## Flow

### 1. Scrobble Creation

When a scrobble is created via `POST /api/v1/scrobbles`, it contains raw user-submitted data:

```ruby
{
  track_name: "Bohemian Rhapsody",
  artist_name: "Queen",
  album_name: "A Night at the Opera",
  duration_ms: 354000,
  played_at: "2025-01-15T20:30:00Z",
  source_app: "goodsongs-ios"
}
```

The scrobble is saved with `metadata_status: pending`.

### 2. Background Job Triggered

The `Scrobble` model has an `after_create_commit` callback that enqueues the enrichment job:

```ruby
# app/models/scrobble.rb
after_create_commit :enqueue_enrichment_job

def enqueue_enrichment_job
  ScrobbleEnrichmentJob.perform_later(id)
end
```

### 3. ScrobbleEnrichmentJob

**Location:** `app/jobs/scrobble_enrichment_job.rb`

The job:
- Runs asynchronously in the background (ActiveJob)
- Retries on network errors with exponential backoff (up to 3 attempts)
- Discards if the scrobble record no longer exists
- Skips if already processed (not `pending`)

```ruby
retry_on Net::OpenTimeout, Net::ReadTimeout, ...,
         wait: :polynomially_longer, attempts: 3

discard_on ActiveRecord::RecordNotFound
```

### 4. ScrobbleEnrichmentService

**Location:** `app/services/scrobble_enrichment_service.rb`

The service performs the actual enrichment with a fallback strategy:

#### Step 1: Try MusicBrainz (Primary Source)

```ruby
def find_recording
  ScrobbleCacheService.get_musicbrainz_recording(
    scrobble.track_name,
    scrobble.artist_name
  )
end
```

Uses cached MusicBrainz lookup (24-hour TTL). Searches for a recording matching the track name and artist name.

**If found:** Proceed with MusicBrainz enrichment.

#### Step 2: Fallback to Discogs

If MusicBrainz doesn't find a match:

```ruby
def find_discogs_recording
  results = ScrobbleCacheService.get_discogs_search(track_name, artist_name)
  # Search through results to find matching track in tracklist
end
```

**If found:** Proceed with Discogs enrichment.

**If not found:** Sets `metadata_status: not_found` and returns.

#### Step 3: Find or Create Band

**From MusicBrainz:**
Resolution order:
1. **Exact MBID match** - Find existing band by MusicBrainz artist ID
2. **Case-insensitive name match** - Find by name, backfill MBID if missing
3. **Create new** - Create band with all available fields

**From Discogs:**
Resolution order:
1. **Exact Discogs artist ID match**
2. **Case-insensitive name match** - Backfill Discogs ID if missing
3. **Create new** - Create band with Discogs data

#### Step 4: Find or Create Album

**From MusicBrainz:**
- Selects the "best" release from available options
- Looks up existing album by MusicBrainz release ID
- Creates new album with cover art from Cover Art Archive

**From Discogs:**
- Looks up existing album by Discogs master ID
- Creates new album with cover art from Discogs

#### Step 5: Find or Create Track

- Looks up existing track by recording ID (MusicBrainz) or track ID (Discogs)
- Creates new track with all available metadata
- Inherits genres from album/band

#### Step 6: Update Scrobble

```ruby
scrobble.update!(
  track: track,
  musicbrainz_recording_id: recording[:mbid],  # Only for MusicBrainz
  metadata_status: :enriched
)
```

## Fields Populated

### Band

| Field | MusicBrainz | Discogs |
|-------|-------------|---------|
| `name` | ✓ | ✓ |
| `musicbrainz_id` | ✓ | - |
| `discogs_artist_id` | - | ✓ |
| `sort_name` | ✓ | - |
| `artist_type` | ✓ (Person, Group, etc.) | - |
| `country` | ✓ (ISO code) | - |
| `genres` | ✓ (top 5) | ✓ (top 5) |
| `spotify_link` | ✓ (from URLs) | - |
| `apple_music_link` | ✓ (from URLs) | - |
| `bandcamp_link` | ✓ (from URLs) | - |
| `youtube_music_link` | ✓ (from URLs) | - |
| `artist_image_url` | ✓ (from Fanart.tv) | - |
| `about` | ✓ (generated bio) | - |

### Album

| Field | MusicBrainz | Discogs |
|-------|-------------|---------|
| `name` | ✓ | ✓ |
| `musicbrainz_release_id` | ✓ | - |
| `discogs_master_id` | - | ✓ |
| `cover_art_url` | ✓ (Cover Art Archive) | ✓ (Discogs images) |
| `release_date` | ✓ | ✓ (year only) |
| `release_type` | ✓ (normalized) | album |
| `country` | ✓ | - |
| `genres` | ✓ (inherited from band) | ✓ |

### Track

| Field | MusicBrainz | Discogs |
|-------|-------------|---------|
| `name` | ✓ | ✓ |
| `musicbrainz_recording_id` | ✓ | - |
| `discogs_track_id` | - | ✓ |
| `duration_ms` | ✓ | ✓ (parsed from M:SS) |
| `isrc` | ✓ | - |
| `track_number` | - | ✓ |
| `genres` | ✓ (inherited) | ✓ (inherited) |

### Release Type Normalization

MusicBrainz release types are normalized to:
- `album`
- `single`
- `ep`
- `compilation`
- `live`
- `remix`
- `soundtrack`
- `other`

## Metadata Status

The `Scrobble` model has a `metadata_status` enum:

| Status | Value | Description |
|--------|-------|-------------|
| `pending` | 0 | Just created, awaiting enrichment |
| `enriched` | 1 | Successfully matched to MusicBrainz or Discogs |
| `not_found` | 2 | Could not find in either source |
| `failed` | 3 | Error during enrichment process |

## External Services

### MusicBrainz API

**Location:** `app/services/musicbrainz_service.rb`

- Base URI: `https://musicbrainz.org/ws/2`
- Rate limited: 1 request per second (enforced via mutex)
- Retries: Up to 3 attempts with exponential backoff
- Custom User-Agent header required

Key methods:
- `find_recording(track_name, artist_name)` - Search and get recording details
- `get_artist(mbid)` - Get full artist details including genres, URLs
- `get_recording(mbid)` - Get recording with artists, releases, ISRCs

### Discogs API

**Location:** `app/services/discogs_service.rb`

- Base URI: `https://api.discogs.com`
- Rate limited: 1 request per second
- Authentication: Consumer key/secret (optional but recommended)
- Retries: Up to 3 attempts with exponential backoff

Key methods:
- `search(track:, artist:)` - Search for releases containing a track
- `get_master(master_id)` - Get master release with tracklist
- `get_release(release_id)` - Get specific release details

### Cover Art Archive

**Location:** `app/services/cover_art_archive_service.rb`

- Base URI: `https://coverartarchive.org`
- Fetches album cover art by MusicBrainz release ID
- Returns redirect URL to actual image (CDN)
- Supports sizes: 250px, 500px, 1200px

### Fanart.tv (Optional)

**Location:** `app/services/fanart_tv_service.rb`

- Base URI: `https://webservice.fanart.tv/v3`
- Requires API key (`FANART_TV_API_KEY` env var)
- Fetches artist images (thumbs, backgrounds, logos)
- Gracefully fails if not configured

## Caching

**Location:** `app/services/scrobble_cache_service.rb`

All external API responses are cached to minimize API calls:

| Cache Key | TTL | Description |
|-----------|-----|-------------|
| `musicbrainz:recording:{hash}` | 24 hours | MusicBrainz recording search results |
| `musicbrainz:recording_detail:{mbid}` | 24 hours | Full recording details |
| `coverart:{release_mbid}` | 24 hours | Cover Art Archive URLs |
| `discogs:search:{hash}` | 24 hours | Discogs search results |
| `discogs:master:{id}` | 24 hours | Discogs master release details |
| `discogs:release:{id}` | 24 hours | Discogs release details |

Cache is invalidated when new scrobbles are submitted.

## Data Model

### Relationships After Enrichment

```
Scrobble
├── belongs_to :user
├── belongs_to :track (after enrichment)
└── musicbrainz_recording_id (string, if from MusicBrainz)

Track
├── belongs_to :band
├── belongs_to :album
├── has_many :scrobbles
├── musicbrainz_recording_id (string, if from MusicBrainz)
├── discogs_track_id (string, if from Discogs)
├── isrc (string)
└── genres (jsonb array)

Album
├── belongs_to :band
├── has_many :tracks
├── musicbrainz_release_id (string, if from MusicBrainz)
├── discogs_master_id (string, if from Discogs)
├── cover_art_url (string)
├── release_type (string)
├── country (string)
└── genres (jsonb array)

Band
├── has_many :albums
├── has_many :tracks
├── musicbrainz_id (string, if from MusicBrainz)
├── discogs_artist_id (string, if from Discogs)
├── artist_image_url (string)
├── sort_name (string)
├── artist_type (string)
├── country (string)
├── genres (jsonb array)
└── streaming links (spotify, apple_music, bandcamp, youtube_music)
```

### Determining Data Source

Records can have data from both sources. To determine the original source:

- **MusicBrainz**: Check for presence of `musicbrainz_*` ID fields
- **Discogs**: Check for presence of `discogs_*` ID fields
- **Both**: A record may have both if initially created from one source and later matched to the other

## Release Selection Algorithm

When multiple releases (albums) contain the same recording, the system selects the "best" one:

```ruby
def select_best_release(releases)
  releases.sort_by do |release|
    [
      release[:status] == 'Official' ? 0 : 1,  # Official first
      release[:date].present? ? 0 : 1,          # Has date
      release[:date].to_s                        # Earlier date
    ]
  end.first
end
```

Priority:
1. Official releases over bootlegs/promos
2. Releases with dates over undated
3. Earlier releases over later ones

## Error Handling

| Error Type | Handling |
|------------|----------|
| Network errors | Job retries with exponential backoff (1s, 2s, 4s) |
| Record not found | Job discarded (scrobble was deleted) |
| MusicBrainz + Discogs not found | `metadata_status: not_found` |
| Any other error | `metadata_status: failed`, logged |

## Batch Enrichment

For bulk operations, the service provides a batch method:

```ruby
ScrobbleEnrichmentService.enrich_batch(scrobbles)
# Returns: { success: 10, not_found: 2, failed: 1 }
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FANART_TV_API_KEY` | No | Fanart.tv API key for artist images |
| `DISCOGS_CONSUMER_KEY` | No | Discogs API consumer key (recommended) |
| `DISCOGS_CONSUMER_SECRET` | No | Discogs API consumer secret (recommended) |

## Performance Considerations

1. **Rate Limiting**: Both MusicBrainz and Discogs enforce rate limits. The mutex ensures compliance even with concurrent jobs.

2. **Caching**: 24-hour cache TTL means repeated scrobbles of the same track don't hit external APIs.

3. **Background Processing**: Enrichment is async, so scrobble submission returns immediately.

4. **Deduplication**: Existing bands/albums/tracks are reused, not duplicated.

5. **Fallback Latency**: Discogs fallback adds latency when MusicBrainz fails, but only for tracks not in MusicBrainz.

## Future Improvements

Potential enhancements:
- Add Spotify API for additional metadata (popularity, audio features)
- Add Wikipedia/Wikidata for artist bios
- Support for classical music with work/composer data
- Periodic re-enrichment of `not_found` scrobbles
- Backfill existing records with new fields
