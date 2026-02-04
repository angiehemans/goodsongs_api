# MusicBrainz Seed Generator

This toolkit processes MusicBrainz JSON dumps and generates Rails seed files for the GoodSongs database. It creates seed data for bands, albums, and tracks with MusicBrainz IDs for future API enrichment.

## Quick Start

```bash
# 1. Download and extract dumps (uses Makefile)
make download
make extract

# 2. Inspect the dumps to verify structure
ruby inspect_dump.rb data/extracted/mbdump/artist

# 3. Generate seed files
make process

# 4. Copy to your Rails app and load
cp data/seeds/*.rb /path/to/goodsongs/db/seeds/musicbrainz/
cd /path/to/goodsongs
rails runner "Dir['db/seeds/musicbrainz/bands_*.rb'].sort.each { |f| load f }"
rails runner "load 'db/seeds/musicbrainz/build_bands_index.rb'"
rails runner "Dir['db/seeds/musicbrainz/albums_*.rb'].sort.each { |f| load f }"
rails runner "Dir['db/seeds/musicbrainz/tracks_*.rb'].sort.each { |f| load f }"
```

## Prerequisites

**Ruby** (any recent version, tested with 3.x)

No gem dependencies for the processing scripts - they use only Ruby standard library.

## File Overview

| Script                      | Purpose                                      |
| --------------------------- | -------------------------------------------- |
| `inspect_dump.rb`           | Analyze dump structure before processing     |
| `process_artists.rb`        | Convert artists → bands seed files           |
| `process_release_groups.rb` | Convert release-groups → albums seed files   |
| `process_recordings.rb`     | Convert recordings → tracks seed files       |
| `fetch_cover_art.rb`        | Batch fetch cover art URLs (run in Rails)    |
| `link_tracks_to_albums.rb`  | Link tracks to albums via API (run in Rails) |
| `Makefile`                  | Orchestrate download/extract/process         |

## Detailed Setup

### 1. Download the MusicBrainz JSON dumps

```bash
# Using Makefile (recommended)
make download

# Or manually:
mkdir -p data/downloads
cd data/downloads
wget https://data.metabrainz.org/pub/musicbrainz/data/json-dumps/20260131-001001/artist.tar.xz
wget https://data.metabrainz.org/pub/musicbrainz/data/json-dumps/20260131-001001/release-group.tar.xz
wget https://data.metabrainz.org/pub/musicbrainz/data/json-dumps/20260131-001001/recording.tar.xz
```

**Sizes:**

- artist.tar.xz: ~2 GB
- release-group.tar.xz: ~1 GB
- recording.tar.xz: ~30 MB

### 2. Extract the archives

```bash
make extract

# Or manually:
mkdir -p data/extracted
tar -xf data/downloads/artist.tar.xz -C data/extracted
tar -xf data/downloads/release-group.tar.xz -C data/extracted
tar -xf data/downloads/recording.tar.xz -C data/extracted
```

After extraction, you'll have:

```
data/extracted/mbdump/
├── artist      (JSONL - one JSON object per line)
├── release-group
└── recording
```

### 3. Inspect the dump structure (recommended)

Before processing, verify the dump format matches what the scripts expect:

```bash
ruby inspect_dump.rb data/extracted/mbdump/artist
ruby inspect_dump.rb data/extracted/mbdump/release-group
ruby inspect_dump.rb data/extracted/mbdump/recording
```

This shows you the fields available and sample records.

## Usage

### Step 1: Process Artists → Bands

```bash
ruby process_artists.rb --input data/downloads/artist/artist --output data/seeds --limit 100000
```

Options:

- `--input` - Path to the extracted artist JSONL file
- `--output` - Directory to write seed files
- `--limit` - Maximum number of artists to process (optional, for testing)
- `--min-tags` - Only include artists with at least N genre tags (optional)

### Step 2: Process Release Groups → Albums

```bash
ruby process_release_groups.rb --input data/downloads/release-group/release-group --output data/seeds --bands-index data/seeds/bands_index.json
```

This requires the bands_index.json file generated in Step 1, which maps MusicBrainz artist IDs to your band IDs.

### Step 3: Process Recordings → Tracks

```bash
ruby process_recordings.rb --input data/downloads/recording/recording --output data/seeds --bands-index data/seeds/bands_index.json --albums-index data/seeds/albums_index.json
```

### Step 4: Load seeds into Rails

Copy the generated seed files to your Rails app:

```bash
cp data/seeds/*.rb /path/to/goodsongs/db/seeds/musicbrainz/
```

Then run:

```bash
rails db:seed:musicbrainz
# Or load individually:
rails runner "load 'db/seeds/musicbrainz/bands_001.rb'"
```

## Output Files

The script generates:

- `bands_001.rb`, `bands_002.rb`, ... - Band seed files (10,000 records each)
- `albums_001.rb`, `albums_002.rb`, ... - Album seed files
- `tracks_001.rb`, `tracks_002.rb`, ... - Track seed files
- `bands_index.json` - Maps musicbrainz_id → band database ID
- `albums_index.json` - Maps musicbrainz_release_id → album database UUID

## Filtering Options

The dumps contain millions of records. You probably want to filter:

### By popularity (recommended)

Artists/releases with more tags are generally more popular:

```bash
ruby process_artists.rb --min-tags 5
```

### By type

Only include groups (bands), not solo artists:

```bash
ruby process_artists.rb --types "Group,Orchestra"
```

### By genre

Only include specific genres:

```bash
ruby process_artists.rb --genres "rock,indie,punk,metal"
```

## Notes

- The script uses `insert_all` for performance (bulk inserts)
- Duplicate MusicBrainz IDs are skipped (uses `ON CONFLICT DO NOTHING`)
- Cover art URLs are not in the dump - see `fetch_cover_art.rb` for batch fetching from Cover Art Archive
- Processing the full dumps takes significant time and disk space
