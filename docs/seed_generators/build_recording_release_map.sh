#!/bin/bash
# build_recording_release_map.sh
# Builds recording_id -> release_group_id mapping from MusicBrainz release dump.
#
# Uses grep -F pre-filtering to process only release lines containing our
# recording IDs, making this fast even on the 20GB release dump.
#
# Prerequisites:
#   - data/downloads/release.tar.xz (download from MusicBrainz)
#   - Track seed files in db/seeds/musicbrainz/tracks_*.rb
#
# Usage:
#   cd docs/seed_generators
#   bash build_recording_release_map.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOWNLOADS="$SCRIPT_DIR/data/downloads"
SEEDS_DATA="$SCRIPT_DIR/data/seeds"
OUTPUT="$REPO_ROOT/db/seeds/musicbrainz/recording_release_map.json"

RELEASE_ARCHIVE="$DOWNLOADS/release.tar.xz"
RECORDING_IDS="$SEEDS_DATA/recording_ids.txt"

mkdir -p "$SEEDS_DATA"

# Step 1: Extract recording IDs from track seed files
echo "Step 1: Extracting recording IDs from track seeds..."
grep -hoP '(?<=musicbrainz_recording_id: ")[0-9a-f-]+' \
  "$REPO_ROOT/db/seeds/musicbrainz/tracks_"*.rb \
  | sort -u > "$RECORDING_IDS"

TOTAL_IDS=$(wc -l < "$RECORDING_IDS")
echo "  Found $TOTAL_IDS unique recording IDs"

# Step 2: Verify release archive exists and is valid
if [ ! -f "$RELEASE_ARCHIVE" ]; then
  echo "Error: $RELEASE_ARCHIVE not found"
  echo "Download it with:"
  echo "  cd $DOWNLOADS"
  echo "  wget https://data.metabrainz.org/pub/musicbrainz/data/json-dumps/20260131-001001/release.tar.xz"
  exit 1
fi

echo ""
echo "Step 2: Streaming release dump through grep pre-filter..."
echo "  This filters ~20GB down to only lines containing our recording IDs."
echo "  Most of the time is xz decompression - processing is fast."
echo ""

# Step 3: Stream, pre-filter with grep -F, then process with Ruby
# - tar streams the decompressed release JSONL
# - grep -F -f quickly filters to only lines containing a target recording ID
# - Ruby script parses filtered JSON and extracts recording -> release-group mapping
tar -xf "$RELEASE_ARCHIVE" --to-stdout mbdump/release 2>/dev/null \
  | grep -F -f "$RECORDING_IDS" \
  | ruby "$SCRIPT_DIR/extract_recording_release_map.rb" \
      --recordings "$RECORDING_IDS" \
      --output "$OUTPUT"

echo ""
echo "Output written to: $OUTPUT"
echo ""
echo "Next step: load the mapping on production with:"
echo "  kamal app exec 'rails runner \"load '\''db/seeds/musicbrainz/link_tracks_to_albums.rb'\''\"'"
