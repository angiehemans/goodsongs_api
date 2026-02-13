# Scrobble Metadata Enrichment Improvement Plan

## Current State Analysis

### Architecture Overview
```
Scrobble Created
    ↓
ScrobbleEnrichmentJob (async)
    ↓
ScrobbleEnrichmentService
    ↓
[Sequential Fallback Chain]
    1. MusicBrainz API (1 req/sec rate limit)
    2. TheAudioDB API
    3. Discogs API
    ↓
Create/Link: Band → Album → Track
    ↓
Fetch Cover Art (blocking)
    1. Cover Art Archive
    2. TheAudioDB fallback
    3. Discogs fallback
```

### Current Issues

#### 1. **Slow Cover Art Fetching**
- Cover art is fetched synchronously during enrichment
- Multiple fallback sources checked sequentially
- If Cover Art Archive fails, adds 2+ more API calls
- **Impact**: Delays entire enrichment, artwork often missing initially

#### 2. **Rate Limiting Bottleneck**
- MusicBrainz enforces 1 request per second
- Each enrichment may need 2-3 MusicBrainz calls (recording + artist + cover art)
- **Impact**: ~3-5 seconds per scrobble minimum

#### 3. **Sequential Fallbacks**
- Sources checked one at a time: MusicBrainz → TheAudioDB → Discogs
- No parallel fetching across sources
- **Impact**: Worst case 6-10+ API calls per scrobble

#### 4. **Job Queue Limitations**
- Production uses `async` adapter (in-process threads)
- No job prioritization or dedicated workers
- Jobs can be lost on server restart
- **Impact**: Unreliable processing, no visibility into queue

#### 5. **No Artwork Pre-fetching**
- Artwork only fetched during full enrichment
- If track/album already exists, artwork may still be missing
- **Impact**: Existing records have no artwork

---

## Proposed Improvements

### Phase 1: Quick Wins (1-2 days)

#### 1.1 Deferred Artwork Fetching
Split enrichment into two stages:
1. **Fast enrichment**: Link scrobble to track/album (no artwork fetch)
2. **Artwork job**: Separate background job for cover art

```ruby
# New job: ArtworkEnrichmentJob
class ArtworkEnrichmentJob < ApplicationJob
  queue_as :low_priority

  def perform(album_id)
    album = Album.find(album_id)
    return if album.cover_art_url.present?

    # Fetch from multiple sources in parallel
    artwork_url = fetch_artwork_parallel(album)
    album.update!(cover_art_url: artwork_url) if artwork_url
  end
end
```

**Benefit**: Scrobbles show up faster, artwork loads in background

#### 1.2 Parallel Artwork Source Fetching
Fetch from all artwork sources simultaneously:

```ruby
def fetch_artwork_parallel(album)
  threads = []
  results = Concurrent::Array.new

  threads << Thread.new { results << fetch_cover_art_archive(album) }
  threads << Thread.new { results << fetch_audiodb_artwork(album) }
  threads << Thread.new { results << fetch_discogs_artwork(album) }

  threads.each { |t| t.join(5) } # 5 second timeout

  # Return first non-nil result, preferring Cover Art Archive
  results.compact.first
end
```

**Benefit**: 3x faster artwork fetching

#### 1.3 Eager Artwork Backfill for Existing Albums
When a scrobble links to an existing album without artwork, queue artwork fetch:

```ruby
# In ScrobbleEnrichmentService#find_or_create_album
if album.cover_art_url.blank?
  ArtworkEnrichmentJob.perform_later(album.id)
end
```

**Benefit**: Fixes missing artwork on existing records

---

### Phase 2: Performance Optimization (3-5 days)

#### 2.1 Switch to Solid Queue
Replace `async` adapter with `solid_queue` for reliable job processing:

```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue

# config/solid_queue.yml
queues:
  - name: critical
    polling_interval: 0.5
  - name: default
    polling_interval: 1
  - name: low_priority
    polling_interval: 5
```

**Queue Priority**:
- `critical`: User-initiated actions (manual refresh)
- `default`: New scrobble enrichment
- `low_priority`: Artwork backfill, batch operations

#### 2.2 Batch Enrichment with Rate Limit Pooling
Process multiple scrobbles efficiently:

```ruby
class BatchEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(scrobble_ids)
    scrobbles = Scrobble.pending.where(id: scrobble_ids)

    # Group by artist to reduce duplicate API calls
    scrobbles.group_by(&:artist_name).each do |artist, artist_scrobbles|
      # Fetch artist once, reuse for all tracks
      artist_data = fetch_artist_data(artist)

      artist_scrobbles.each do |scrobble|
        enrich_with_cached_artist(scrobble, artist_data)
        sleep(0.5) # Reduced delay since artist is cached
      end
    end
  end
end
```

**Benefit**: Reduces API calls by 40-60% for users with multiple tracks by same artist

#### 2.3 Smart Source Selection
Skip unlikely sources based on patterns:

```ruby
def select_sources_for_track(track_name, artist_name)
  sources = [:musicbrainz]

  # TheAudioDB is better for mainstream artists
  sources << :audiodb if likely_mainstream?(artist_name)

  # Discogs is better for electronic/DJ/vinyl releases
  sources << :discogs if likely_electronic?(artist_name, track_name)

  sources
end
```

---

### Phase 3: User Experience (2-3 days)

#### 3.1 Real-time Enrichment Status
Add WebSocket/polling for enrichment progress:

```ruby
# New endpoint: GET /api/v1/scrobbles/:id/enrichment_status
def enrichment_status
  scrobble = current_user.scrobbles.find(params[:id])

  render json: {
    status: scrobble.metadata_status,
    has_artwork: scrobble.effective_artwork_url.present?,
    estimated_completion: estimate_completion(scrobble)
  }
end
```

#### 3.2 Instant Artwork from Last.fm
For users with Last.fm connected, use their scrobble data for immediate artwork:

```ruby
# When creating scrobble from Last.fm sync
def create_scrobble_with_lastfm_art(lastfm_track)
  scrobble = Scrobble.create!(
    track_name: lastfm_track[:name],
    artist_name: lastfm_track[:artist],
    # Use Last.fm image immediately as temporary artwork
    temporary_artwork_url: lastfm_track[:image]
  )
end
```

**Benefit**: Immediate artwork display, replaced with higher quality later

#### 3.3 User Artwork Preferences Memory
Remember user's artwork choices for future scrobbles:

```ruby
# New table: user_artwork_preferences
# user_id, artist_name, album_name, preferred_artwork_url

def apply_user_preference(scrobble)
  pref = UserArtworkPreference.find_by(
    user: scrobble.user,
    artist_name: scrobble.artist_name.downcase,
    album_name: scrobble.album_name&.downcase
  )

  scrobble.update!(preferred_artwork_url: pref.artwork_url) if pref
end
```

---

### Phase 4: Advanced Optimizations (Future)

#### 4.1 Pre-computed Popular Track Cache
Cache enrichment data for popular tracks:

```ruby
# Nightly job to pre-enrich top 10,000 tracks
class PopularTrackCacheJob < ApplicationJob
  def perform
    Track.joins(:scrobbles)
         .group('tracks.id')
         .order('COUNT(scrobbles.id) DESC')
         .limit(10_000)
         .each do |track|
      CachedTrackEnrichment.upsert(track)
    end
  end
end
```

#### 4.2 Collaborative Enrichment
Use successful enrichments from other users:

```ruby
def find_existing_enrichment(track_name, artist_name)
  # Check if another user's scrobble with same track was enriched
  existing = Scrobble.enriched
                     .where('LOWER(track_name) = ?', track_name.downcase)
                     .where('LOWER(artist_name) = ?', artist_name.downcase)
                     .where.not(track_id: nil)
                     .first

  existing&.track
end
```

#### 4.3 ML-based Source Prediction
Train model to predict best source for a track:
- Input: artist name, track name, album name
- Output: probability scores for each source
- Skip low-probability sources

---

## Implementation Priority

| Phase | Improvement | Effort | Impact | Priority |
|-------|-------------|--------|--------|----------|
| 1.1 | Deferred Artwork | 4h | High | **P0** |
| 1.2 | Parallel Artwork Fetch | 2h | High | **P0** |
| 1.3 | Eager Artwork Backfill | 1h | Medium | **P1** |
| 2.1 | Solid Queue | 4h | High | **P1** |
| 2.2 | Batch Enrichment | 6h | High | **P1** |
| 2.3 | Smart Source Selection | 4h | Medium | **P2** |
| 3.1 | Real-time Status | 4h | Medium | **P2** |
| 3.2 | Last.fm Instant Art | 2h | High | **P1** |
| 3.3 | User Preferences Memory | 4h | Medium | **P2** |

---

## Success Metrics

1. **Time to First Artwork**: Target < 5 seconds (currently 10-30+ seconds)
2. **Enrichment Success Rate**: Target > 95% (measure current baseline)
3. **Artwork Coverage**: Target > 90% of scrobbles have artwork within 1 minute
4. **Job Queue Depth**: Monitor for backlog during high-volume periods

---

## Next Steps

1. [ ] Measure current enrichment times and success rates (baseline)
2. [ ] Implement Phase 1 improvements (deferred + parallel artwork)
3. [ ] Test with high-volume scrobble submission
4. [ ] Monitor and iterate
