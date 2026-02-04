# MusicBrainz Seed Generator Makefile
#
# Usage:
#   make download    - Download MusicBrainz JSON dumps
#   make extract     - Extract downloaded archives
#   make process     - Generate seed files (artists, albums, tracks)
#   make all         - Do everything

DUMP_DATE = 20260131-001001
DUMP_URL = https://data.metabrainz.org/pub/musicbrainz/data/json-dumps/$(DUMP_DATE)

DATA_DIR = data
DOWNLOAD_DIR = $(DATA_DIR)/downloads
EXTRACT_DIR = $(DATA_DIR)/extracted
SEEDS_DIR = $(DATA_DIR)/seeds

# Filtering options - adjust these for your needs
ARTIST_LIMIT = 100000
ARTIST_MIN_TAGS = 3
RELEASE_TYPES = album,ep,single

.PHONY: all download extract process clean help

help:
	@echo "MusicBrainz Seed Generator"
	@echo ""
	@echo "Commands:"
	@echo "  make download    Download MusicBrainz JSON dumps (~3GB)"
	@echo "  make extract     Extract downloaded archives"
	@echo "  make process     Generate Rails seed files"
	@echo "  make all         Download, extract, and process"
	@echo "  make clean       Remove all generated files"
	@echo ""
	@echo "Configuration (edit Makefile to change):"
	@echo "  ARTIST_LIMIT     = $(ARTIST_LIMIT)"
	@echo "  ARTIST_MIN_TAGS  = $(ARTIST_MIN_TAGS)"
	@echo "  RELEASE_TYPES    = $(RELEASE_TYPES)"

all: download extract process

# Create directories
$(DOWNLOAD_DIR):
	mkdir -p $(DOWNLOAD_DIR)

$(EXTRACT_DIR):
	mkdir -p $(EXTRACT_DIR)

$(SEEDS_DIR):
	mkdir -p $(SEEDS_DIR)

# Download dumps
download: $(DOWNLOAD_DIR)
	@echo "Downloading MusicBrainz dumps..."
	cd $(DOWNLOAD_DIR) && wget -nc $(DUMP_URL)/artist.tar.xz || true
	cd $(DOWNLOAD_DIR) && wget -nc $(DUMP_URL)/release-group.tar.xz || true
	cd $(DOWNLOAD_DIR) && wget -nc $(DUMP_URL)/recording.tar.xz || true
	@echo "Download complete!"

# Extract archives
extract: $(EXTRACT_DIR)
	@echo "Extracting archives..."
	@if [ -f $(DOWNLOAD_DIR)/artist.tar.xz ]; then \
		echo "Extracting artist.tar.xz..."; \
		tar -xf $(DOWNLOAD_DIR)/artist.tar.xz -C $(EXTRACT_DIR); \
	fi
	@if [ -f $(DOWNLOAD_DIR)/release-group.tar.xz ]; then \
		echo "Extracting release-group.tar.xz..."; \
		tar -xf $(DOWNLOAD_DIR)/release-group.tar.xz -C $(EXTRACT_DIR); \
	fi
	@if [ -f $(DOWNLOAD_DIR)/recording.tar.xz ]; then \
		echo "Extracting recording.tar.xz..."; \
		tar -xf $(DOWNLOAD_DIR)/recording.tar.xz -C $(EXTRACT_DIR); \
	fi
	@echo "Extraction complete!"

# Process all entities
process: process-artists process-albums process-tracks

process-artists: $(SEEDS_DIR)
	@echo "Processing artists..."
	ruby process_artists.rb \
		--input $(EXTRACT_DIR)/mbdump/artist \
		--output $(SEEDS_DIR) \
		--limit $(ARTIST_LIMIT) \
		--min-tags $(ARTIST_MIN_TAGS)

process-albums: $(SEEDS_DIR)
	@echo "Processing release groups..."
	ruby process_release_groups.rb \
		--input $(EXTRACT_DIR)/mbdump/release-group \
		--output $(SEEDS_DIR) \
		--bands-index $(SEEDS_DIR)/bands_index.json \
		--types $(RELEASE_TYPES)

process-tracks: $(SEEDS_DIR)
	@echo "Processing recordings..."
	ruby process_recordings.rb \
		--input $(EXTRACT_DIR)/mbdump/recording \
		--output $(SEEDS_DIR) \
		--bands-index $(SEEDS_DIR)/bands_index.json

# Test with small sample
test:
	@echo "Running test with 1000 artists..."
	mkdir -p $(SEEDS_DIR)
	ruby process_artists.rb \
		--input $(EXTRACT_DIR)/mbdump/artist \
		--output $(SEEDS_DIR) \
		--limit 1000 \
		--min-tags 1

# Clean up
clean:
	rm -rf $(DATA_DIR)

clean-seeds:
	rm -rf $(SEEDS_DIR)
