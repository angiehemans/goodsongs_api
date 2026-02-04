# Loading Band Seeds on Production

This guide covers how to load the updated MusicBrainz band seeds (with city, region, and slug) onto the production database via Kamal.

## Prerequisites

- Kamal CLI installed locally
- SSH access to the production server (143.198.62.246)
- The seed files in `db/seeds/musicbrainz/bands_*.rb` committed and deployed

## What the seeds do

The seed files use `upsert_all` with `unique_by: :musicbrainz_id`, which means:

- **New bands** (no matching `musicbrainz_id`) are inserted
- **Existing bands** (matching `musicbrainz_id`) are updated with the new `city`, `region`, and `slug` fields
- **Non-MusicBrainz bands** (user-submitted, no `musicbrainz_id`) are left untouched

Each seed file also resolves slug conflicts at runtime, so it won't fail if a user-created band already has a slug like `van-halen`.

## Loading the seeds

After deploying the code with the updated seed files, run each file in order:

```bash
# Load all 4 band seed files sequentially
kamal app exec 'bin/rails runner "Dir[\"db/seeds/musicbrainz/bands_*.rb\"].sort.each { |f| puts \"Loading #{f}...\"; load f }"'
```

Or load them one at a time if you want to monitor progress:

```bash
kamal app exec 'bin/rails runner "load \"db/seeds/musicbrainz/bands_001.rb\""'
kamal app exec 'bin/rails runner "load \"db/seeds/musicbrainz/bands_002.rb\""'
kamal app exec 'bin/rails runner "load \"db/seeds/musicbrainz/bands_003.rb\""'
kamal app exec 'bin/rails runner "load \"db/seeds/musicbrainz/bands_004.rb\""'
```

## Verification

After loading, verify the data looks correct:

```bash
kamal app exec 'bin/rails runner "
puts \"Total bands: #{Band.count}\"
puts \"Bands with city: #{Band.where.not(city: [nil, \\\"\\\"]).count}\"
puts \"Bands with region: #{Band.where.not(region: [nil, \\\"\\\"]).count}\"
puts \"Bands with slug: #{Band.where.not(slug: [nil, \\\"\\\"]).count}\"
puts \"Duplicate slugs: #{Band.group(:slug).having(\\\"count(*) > 1\\\").count.length}\"
"'
```

Expected results:

| Metric | Expected |
|---|---|
| Bands with city | ~22,700 (62% of MusicBrainz bands) |
| Bands with region | ~12,000 (33%) |
| Bands with slug | 100% of all bands |
| Duplicate slugs | 0 |

You can also spot-check specific bands:

```bash
kamal app exec 'bin/rails runner "
[\"nirvana\", \"radiohead\", \"metallica\"].each do |s|
  b = Band.find_by(slug: s)
  puts \"#{b.name}: city=#{b.city}, slug=#{b.slug}\" if b
end
"'
```

## Rebuilding the bands_db_index.json

If you later need to re-link albums/tracks to bands (e.g., after re-importing), rebuild the DB index:

```bash
kamal app exec 'bin/rails runner "load \"db/seeds/musicbrainz/build_bands_index.rb\""'
```

## Regenerating seeds from scratch

If you need to regenerate the seed files (e.g., from a newer MusicBrainz dump):

```bash
cd docs/seed_generators
make download    # Downloads artist.tar.xz (~1.5GB)
make extract     # Extracts to data/extracted/mbdump/artist (~16GB)

ruby process_artists.rb \
  --input data/extracted/mbdump/artist \
  --output data/seeds \
  --limit 100000 \
  --min-tags 3 \
  --countries US,CA,GB,AU,NZ

cp data/seeds/bands_*.rb ../../db/seeds/musicbrainz/
make clean       # Remove downloaded/extracted data
```
