# GoodSongs Music Database — Planning Document

## Problem

GoodSongs currently depends on external APIs (MusicBrainz, Discogs, Last.fm) for all music metadata — search, enrichment, cover art, and artist info. This causes:

- **Slow search** — every query makes multiple round-trips to third-party APIs with rate limiting (1 req/sec for MusicBrainz, 1 req/sec for Discogs)
- **Fragile enrichment** — scrobble enrichment fails when external APIs are down or rate-limited
- **No data ownership** — we can't extend, correct, or add to the music data
- **Missing coverage** — underground/indie/local artists often have incomplete or no entries in MusicBrainz/Discogs

## Proposal

Build a local PostgreSQL music database seeded from MusicBrainz data dumps, then extend it with user-submitted metadata. This gives us fast local search, reliable enrichment, and the ability to grow coverage beyond what MusicBrainz offers.

---

## MusicBrainz as a Starting Point

### What's Available

MusicBrainz provides full PostgreSQL data dumps updated **twice weekly**. The core data is licensed under **CC0 (public domain)** — free for commercial use with no attribution required.

The dump includes:

| Entity | Approximate Count | Relevant Tables |
|---|---|---|
| Artists | ~2.2M | `artist`, `artist_alias`, `artist_type` |
| Recordings (tracks) | ~30M+ | `recording`, `isrc` |
| Releases (albums) | ~3.4M | `release`, `release_group`, `medium`, `track` |
| Labels | ~200K+ | `label` |
| Areas | ~110K+ | `area` (countries, cities) |
| Genres/Tags | Extensive | `tag`, `*_tag` tables |

### Storage Requirements

| Option | Disk Space | Notes |
|---|---|---|
| Full MB database + search indexes | 60GB+ | Everything including edit history |
| Core tables only (artists, recordings, releases) | ~15-25GB | What we'd actually need |
| Selective import (popular content first) | ~2-5GB | Phased approach, start small |

### Import Options

1. **Full PostgreSQL dump** — Load the raw MB dump into a separate schema or database, then ETL into our tables
2. **JSON data dumps** — Parse JSON exports and insert selectively
3. **MusicBrainz Docker mirror** — Run a full MB server locally for API access (overkill for our needs)

**Recommended: Option 1** — Import the PostgreSQL dump into a staging schema, then run a migration script to map MB data into our `bands`, `albums`, and `tracks` tables.

---

## Prerequisite: Consolidate `artists` into `bands`

The codebase currently has two tables representing musical artists:

- **`bands`** (integer pk) — The main platform entity. Has reviews, events, ownership, location, streaming links, slugs, images, disabled flag. Referenced in 25+ files with a 149-line model.
- **`artists`** (UUID pk) — Lightweight metadata table used only by scrobble enrichment. Has name, musicbrainz_artist_id, image_url, bio. Referenced in 4-5 files with an 11-line model.

These must be consolidated into a single `bands` table before building the music database. The `source` column distinguishes canonical metadata entries from user-owned band profiles:

- `source: :musicbrainz` + no `user_id` → canonical metadata (imported or enrichment-created)
- `source: :user_submitted` + `user_id` → user-owned band profile

### Migration Steps

1. Add missing canonical metadata columns to `bands` (the few fields `artists` has that `bands` doesn't)
2. Migrate existing `artists` data into `bands`, matching on `musicbrainz_id` where possible
3. Update `albums` and `tracks` foreign keys: `artist_id` → `band_id` (referencing `bands`)
4. Update `ScrobbleEnrichmentService` to find/create `Band` records instead of `Artist`
5. Update `Album` and `Track` models: `belongs_to :band` instead of `belongs_to :artist`
6. Update serializers in scrobbles controller to use band associations
7. Drop the `artists` table and `Artist` model

---

## Proposed Data Model Changes

### Current Schema (After Consolidation)

The `bands` table becomes the single source for all musical artists:

```
bands (integer pk) — existing table, extended
├── name, slug, user_id, about, city, region, latitude, longitude
├── musicbrainz_id, lastfm_artist_name, lastfm_image_url
├── spotify_link, bandcamp_link, apple_music_link, youtube_music_link
├── artist_image_url, external_image_url, disabled
├── [new] source, genres, verified, artist_type, country, sort_name, aliases
├── [new] discogs_artist_id, bio, submitted_by_id

albums (UUID pk)
├── name, band_id → bands, musicbrainz_release_id, cover_art_url, release_date

tracks (UUID pk)
├── name, band_id → bands, album_id → albums, duration_ms,
│   musicbrainz_recording_id, isrc
```

### Additions Needed

```sql
-- Extend bands with canonical metadata fields
ALTER TABLE bands ADD COLUMN source INTEGER DEFAULT 0;
  -- 0=musicbrainz, 1=user_submitted
ALTER TABLE bands ADD COLUMN discogs_artist_id VARCHAR;
ALTER TABLE bands ADD COLUMN country VARCHAR(100);
ALTER TABLE bands ADD COLUMN artist_type VARCHAR(50);
  -- person, group, orchestra, choir, etc.
ALTER TABLE bands ADD COLUMN sort_name VARCHAR;
ALTER TABLE bands ADD COLUMN aliases JSONB DEFAULT '[]';
ALTER TABLE bands ADD COLUMN genres JSONB DEFAULT '[]';
ALTER TABLE bands ADD COLUMN verified BOOLEAN DEFAULT FALSE;
ALTER TABLE bands ADD COLUMN bio TEXT;
ALTER TABLE bands ADD COLUMN submitted_by_id BIGINT REFERENCES users(id);

-- Extend albums
ALTER TABLE albums ADD COLUMN source INTEGER DEFAULT 0;
ALTER TABLE albums ADD COLUMN band_id BIGINT REFERENCES bands(id);
  -- replaces artist_id (UUID) → band_id (integer)
ALTER TABLE albums ADD COLUMN discogs_master_id VARCHAR;
ALTER TABLE albums ADD COLUMN release_type VARCHAR(50);
  -- album, single, ep, compilation, live, remix, soundtrack
ALTER TABLE albums ADD COLUMN genres JSONB DEFAULT '[]';
ALTER TABLE albums ADD COLUMN label VARCHAR;
ALTER TABLE albums ADD COLUMN country VARCHAR(100);
ALTER TABLE albums ADD COLUMN track_count INTEGER;
ALTER TABLE albums ADD COLUMN verified BOOLEAN DEFAULT FALSE;
ALTER TABLE albums ADD COLUMN submitted_by_id BIGINT REFERENCES users(id);

-- Extend tracks
ALTER TABLE tracks ADD COLUMN source INTEGER DEFAULT 0;
ALTER TABLE tracks ADD COLUMN band_id BIGINT REFERENCES bands(id);
  -- replaces artist_id (UUID) → band_id (integer)
ALTER TABLE tracks ADD COLUMN discogs_track_id VARCHAR;
ALTER TABLE tracks ADD COLUMN track_number INTEGER;
ALTER TABLE tracks ADD COLUMN disc_number INTEGER DEFAULT 1;
ALTER TABLE tracks ADD COLUMN genres JSONB DEFAULT '[]';
ALTER TABLE tracks ADD COLUMN verified BOOLEAN DEFAULT FALSE;
ALTER TABLE tracks ADD COLUMN submitted_by_id BIGINT REFERENCES users(id);

-- New: band_aliases for search (alternative names, misspellings, etc.)
CREATE TABLE band_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  band_id BIGINT NOT NULL REFERENCES bands(id) ON DELETE CASCADE,
  name VARCHAR NOT NULL,
  locale VARCHAR(10),
  created_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_band_aliases_name ON band_aliases USING gin (name gin_trgm_ops);

-- New: full-text search indexes
CREATE INDEX idx_bands_name_trgm ON bands USING gin (name gin_trgm_ops);
CREATE INDEX idx_albums_name_trgm ON albums USING gin (name gin_trgm_ops);
CREATE INDEX idx_tracks_name_trgm ON tracks USING gin (name gin_trgm_ops);
```

> **Note:** The `gin_trgm_ops` indexes require the `pg_trgm` PostgreSQL extension. This enables fast fuzzy/partial text matching (e.g., searching "cold" matches "Coldplay"). Add via `CREATE EXTENSION IF NOT EXISTS pg_trgm;` in a migration.

---

## Architecture

### Search Flow (After Migration)

```
User searches "Yellow by Coldplay"
        │
        ▼
  Local DB (PostgreSQL full-text / trigram search)
        │
        ├── Found? → Return results instantly (<50ms)
        │
        └── Not found? → Fallback to MusicBrainz/Discogs API
                │
                └── Results found? → Store in local DB for next time
                                     Return to user
```

### Enrichment Flow (After Migration)

```
Scrobble created
        │
        ▼
  Search local DB by track_name + artist_name
        │
        ├── Match found → Link scrobble to track (instant, no API call)
        │
        └── No match → Call MusicBrainz API (existing flow)
                │
                └── Found? → Create band/album/track locally
                             Link scrobble
```

### Data Freshness

- **Initial seed:** One-time import from MusicBrainz dump
- **Periodic sync:** Weekly job to import new/updated MB data (incremental via replication packets)
- **On-demand:** Cache-miss results from API fallback are stored locally
- **User submissions:** Band owners add their catalog; fan reviews create missing entries

---

## User Submission System

### Band Accounts — Direct Submission

Band account owners can add music directly for their own band. No admin review is needed since they are the authoritative source for their own catalog.

**What they can submit:**
- Albums for their band — title, year, cover art URL, genre, tracklist
- Tracks for their band — title, album, duration, track number

**API Endpoints:**
```
POST   /api/v1/bands/:slug/albums     — Add an album to the band's catalog
POST   /api/v1/bands/:slug/tracks     — Add a track to the band's catalog
PATCH  /api/v1/bands/:slug/albums/:id — Update album metadata
PATCH  /api/v1/bands/:slug/tracks/:id — Update track metadata
DELETE /api/v1/bands/:slug/albums/:id — Remove an album
DELETE /api/v1/bands/:slug/tracks/:id — Remove a track
GET    /api/v1/bands/:slug/catalog    — Get full band catalog (albums + tracks)
```

**Validation:**
- User must own the band
- Album: title required, duplicate detection against existing band albums
- Track: title required, linked to the band record
- All records created with `source: :user_submitted` and `verified: true` (owner-verified)

### Fan Accounts — Implicit Submission via Reviews

When a fan submits a review for a track that doesn't exist in the local database, the track/artist/album metadata from the review is automatically added. No separate submission flow needed — the database grows organically as users review music.

**Flow:**
1. Fan creates a review with `band_name`, `song_name`, `artwork_url`
2. Review creation checks if the track/artist exists in local DB
3. If not found, creates the band and track records with `source: :user_submitted`, `verified: false`
4. External API lookup (MusicBrainz/Discogs) runs async to enrich and verify the new records

**Validation:**
- Duplicate detection: fuzzy match band name and track name before creating new records
- Records from reviews start as `verified: false` until enriched by external API data

---

## Implementation Phases

### Phase 0 — Consolidate `artists` into `bands`

**Goal:** Eliminate the duplicate `artists` table and make `bands` the single source for all musical artists.

**Work:**
- Add columns to `bands`: `bio` (from artists), `source`, `verified`, `genres`, `artist_type`, `country`, `sort_name`, `aliases`, `discogs_artist_id`, `submitted_by_id`
- Migrate existing `artists` records into `bands`:
  - Match by `musicbrainz_artist_id` ↔ `musicbrainz_id` where both exist (merge data)
  - Create new `bands` records for unmatched artists (set `source: :musicbrainz`, no `user_id`)
- Add `band_id` column to `albums` and `tracks`, populate from artist→band mapping
- Drop old `artist_id` columns from `albums` and `tracks`
- Update models: `Album belongs_to :band`, `Track belongs_to :band`, `Band has_many :albums, :tracks`
- Update `ScrobbleEnrichmentService` to find/create `Band` records instead of `Artist`
- Update scrobble serializers to use band associations
- Update `MetadataRefreshJob` and `FetchArtistImageJob` for new associations
- Drop `artists` table and `Artist` model

**Files affected:**
- `app/models/artist.rb` → delete
- `app/models/band.rb` → add `has_many :albums`, `has_many :tracks`
- `app/models/album.rb` → `belongs_to :band`
- `app/models/track.rb` → `belongs_to :band`
- `app/services/scrobble_enrichment_service.rb` → Artist → Band
- `app/controllers/api/v1/scrobbles_controller.rb` → update serializers
- `app/jobs/scrobble_enrichment_job.rb` → minor updates
- `app/jobs/metadata_refresh_job.rb` → Artist → Band
- `db/migrate/` → new migration

### Phase 1 — Schema Extensions & Local Search

**Goal:** Add new columns/indexes to `bands`, `albums`, and `tracks`, build a local search endpoint.

**Work:**
- Migration to add remaining music database columns (`genres`, `release_type`, `track_number`, etc.) and trigram indexes
- Enable `pg_trgm` extension
- Create `band_aliases` table
- New `MusicSearchService` that queries local DB with trigram matching
- New unified search endpoint (`GET /api/v1/search`) that checks local DB first, falls back to external APIs
- Store API fallback results into local tables (cache-through pattern)

**Impact:** Immediate search speed improvement for any band/track already in our DB from scrobble enrichment and reviews.

### Phase 2 — MusicBrainz Data Import

**Goal:** Seed both development and production databases with a selective MusicBrainz import.

**Work:**
- Rake task to download and load MB PostgreSQL dump into a staging schema
- ETL script to map MB entities → our `bands`, `albums`, `tracks` tables
- **Selective import filters:**
  - Artists → bands: must have at least one recording with an ISRC
  - Releases → albums: must have cover art available via Cover Art Archive
  - Recordings → tracks: import those linked to selected bands/albums
  - Store cover art as external URLs (Cover Art Archive links)
- Merge with existing bands by `musicbrainz_id` (don't create duplicates)
- Set `source: :musicbrainz` and `verified: true` on imported records
- Schedule weekly incremental sync job using MB replication packets

**Local development seeding:**
1. Download MB dump locally (`rake musicbrainz:download`)
2. Load into staging schema (`rake musicbrainz:load_staging`)
3. Run ETL into app tables (`rake musicbrainz:import`) — can use `LIMIT=10000` for a smaller dev dataset
4. Clean up staging schema (`rake musicbrainz:drop_staging`)

**Production seeding:**
1. Download the MB PostgreSQL dump on the production server (or a worker instance with DB access)
2. Load into a `musicbrainz_staging` schema on the production database — this avoids touching live tables during the multi-hour load
3. Run the ETL rake task (`rake musicbrainz:import RAILS_ENV=production`) in batches to avoid long-running transactions and memory bloat
4. The ETL merges with existing production `bands` by `musicbrainz_id` — existing user-owned bands and enrichment-created bands are preserved, not duplicated
5. Drop the staging schema after import completes
6. Verify counts: `Band.where(source: :musicbrainz).count`, `Album.count`, `Track.count`
7. Run the weekly incremental sync job to keep production data fresh going forward

**Production considerations:**
- Run the initial import during low-traffic hours — the ETL writes in batches but will generate DB load
- Use a database snapshot/backup before starting the import
- The staging schema load is read-only against production tables, so the app can stay online during that step
- The ETL step does writes to `bands`, `albums`, `tracks` — monitor DB connections and query latency
- If the production DB is on a managed service (e.g., RDS, Cloud SQL), ensure sufficient disk space for the staging schema (~15-25GB temporarily)

### Phase 3 — User Submissions

**Goal:** Let band accounts manage their own catalog and grow the database through fan reviews.

**Work:**
- Band catalog API endpoints (`/api/v1/bands/:slug/albums`, `/api/v1/bands/:slug/tracks`, etc.)
- Authorization: only band owners can manage their catalog
- Update review creation flow to auto-create missing bands/tracks in local DB
- Duplicate detection using trigram similarity before creating new records
- Async enrichment job to verify and enhance user-submitted records via MusicBrainz/Discogs lookup

### Phase 4 — Reduce External API Dependency

**Goal:** Use external APIs only as a last resort.

**Work:**
- Update `ScrobbleEnrichmentService` to search local DB before calling MusicBrainz API
- Update `DiscogsSearchController` and `MusicbrainzSearchController` to search local DB first
- Monitor API fallback rate — goal is <5% of searches needing external calls

---

## Trade-offs & Considerations

### Storage
- Selective MB import (artists with ISRCs, albums with cover art) should be ~2-5GB.
- Cover art stays as external URLs, so no additional storage cost for images.

### Data Quality
- MusicBrainz data is community-curated and generally high quality, but has inconsistencies (duplicate artists, wrong release dates).
- Band-submitted data is owner-verified and trustworthy. Fan-contributed data (from reviews) starts unverified and gets enriched async.
- The `verified` flag distinguishes confirmed data from unverified entries.

### Maintenance
- MusicBrainz updates twice weekly. Weekly incremental sync via replication packets keeps data fresh.
- Source-of-truth rules: MB data is canonical for `source: :musicbrainz` records, band owner data is canonical for `source: :user_submitted` records on their own band.

### Performance
- Selective import keeps trigram indexes manageable (not 30M+ rows).
- PostgreSQL full-text search (`tsvector`) handles phrase matching; trigram indexes (`pg_trgm`) handle fuzzy/partial matching. Both can be used together.
- Revisit Elasticsearch/Meilisearch if search latency or relevance becomes an issue at scale.

### Licensing
- MusicBrainz core data is CC0 — no restrictions on use.
- We link to Cover Art Archive URLs rather than hosting images, avoiding per-image license concerns.
- Discogs stays as API-only fallback — no data import, no licensing concerns.

---

## Decisions

1. **Table consolidation** — Drop the `artists` table and consolidate into `bands`. The `bands` table is the primary platform entity (reviews, events, ownership, 25+ file references) while `artists` is a lightweight duplicate used only by scrobble enrichment. The `source` column distinguishes canonical metadata entries (`source: :musicbrainz`, no `user_id`) from user-owned band profiles (`source: :user_submitted`, has `user_id`). This is a prerequisite (Phase 0) before the music database work begins.
2. **Import scope** — Selective import: artists, recordings, albums, and cover art links. Filter to artists with ISRCs/recordings and albums with cover art. This keeps the initial dataset manageable (~2-5GB) while covering the most useful catalog.
3. **Cover art storage** — Link to external URLs (Cover Art Archive, etc.) for now. Revisit hosting locally later if needed.
4. **Search technology** — PostgreSQL full-text search (`tsvector`) with trigram indexes (`pg_trgm`) for fuzzy matching. Revisit Elasticsearch/Meilisearch later if search demands outgrow PostgreSQL.
5. **User submissions** — Two paths for data entry:
   - **Band accounts** can submit music directly for their own band (albums, tracks). No admin review needed — they own the data.
   - **Fan accounts** contribute implicitly: when a fan submits a review for a track that doesn't exist in the database, the track/band/album metadata from the review is added to the local DB automatically.
   - No general-purpose open submission form. Data grows organically through platform usage.
6. **Discogs data** — Keep Discogs as an API-only fallback. Do not import Discogs data into the local database.
