# frozen_string_literal: true

namespace :images do
  desc "Backfill cached images from external URLs (Cover Art Archive and AudioDB only)"
  task backfill: :environment do
    puts "Starting image backfill..."

    backfill_album_covers
    backfill_band_images

    puts "Backfill jobs queued successfully!"
  end

  desc "Backfill album cover art from Cover Art Archive"
  task backfill_albums: :environment do
    backfill_album_covers
  end

  desc "Backfill band artist images from AudioDB/Wikipedia"
  task backfill_bands: :environment do
    backfill_band_images
  end

  desc "Show caching statistics"
  task stats: :environment do
    puts "\n=== Image Caching Statistics ===\n\n"

    # Album stats
    total_albums = Album.count
    albums_with_cover = Album.where.not(cover_art_url: [nil, '']).count
    # Count cached albums by checking Active Storage directly
    albums_cached = ActiveStorage::Attachment.where(record_type: 'Album', name: 'cached_cover_art').count

    puts "Albums:"
    puts "  Total: #{total_albums}"
    puts "  With cover art URL: #{albums_with_cover}"
    puts "  Cached locally: #{albums_cached}"
    puts "  Cache rate: #{albums_with_cover > 0 ? (albums_cached * 100.0 / albums_with_cover).round(1) : 0}%"
    puts ""

    # Band stats
    total_bands = Band.count
    bands_with_image = Band.where.not(artist_image_url: [nil, '']).count
    bands_cached = ActiveStorage::Attachment.where(record_type: 'Band', name: 'cached_artist_image').count

    puts "Bands:"
    puts "  Total: #{total_bands}"
    puts "  With artist image URL: #{bands_with_image}"
    puts "  Cached locally: #{bands_cached}"
    puts "  Cache rate: #{bands_with_image > 0 ? (bands_cached * 100.0 / bands_with_image).round(1) : 0}%"
    puts ""

    # Source breakdown
    puts "Album cover sources:"
    Album.where.not(cover_art_source: nil).group(:cover_art_source).count.each do |source, count|
      puts "  #{source}: #{count}"
    end
    puts ""

    puts "Band image sources:"
    Band.where.not(artist_image_source: nil).group(:artist_image_source).count.each do |source, count|
      puts "  #{source}: #{count}"
    end
  end

  private

  def backfill_album_covers
    # Find albums with cover art URLs from cacheable sources that aren't cached yet
    albums = Album.where.not(cover_art_url: [nil, ''])
    total_checked = 0
    total_queued = 0

    puts "Checking albums for caching..."

    albums.find_each do |album|
      total_checked += 1

      # Skip if already cached
      next if album.cached_cover_art.attached?

      source = ImageCachingService.detect_source(album.cover_art_url)

      # Only cache from approved sources
      next unless ImageCachingService.cacheable_source?(source)

      CacheExternalImageJob.perform_later(
        record_type: 'Album',
        record_id: album.id,
        attribute: 'cover_art',
        url: album.cover_art_url,
        source: source
      )
      total_queued += 1

      print "." if total_queued % 100 == 0
    end

    puts "\nChecked #{total_checked} albums, queued #{total_queued} for caching."
  end

  def backfill_band_images
    # Find bands with artist image URLs that aren't cached yet
    bands = Band.where.not(artist_image_url: [nil, ''])
    total_checked = 0
    total_queued = 0

    puts "Checking bands for caching..."

    bands.find_each do |band|
      total_checked += 1

      # Skip if already cached
      next if band.cached_artist_image.attached?

      source = ImageCachingService.detect_source(band.artist_image_url)

      # Only cache from approved sources
      next unless ImageCachingService.cacheable_source?(source)

      CacheExternalImageJob.perform_later(
        record_type: 'Band',
        record_id: band.id,
        attribute: 'artist_image',
        url: band.artist_image_url,
        source: source
      )
      total_queued += 1

      print "." if total_queued % 100 == 0
    end

    puts "\nChecked #{total_checked} bands, queued #{total_queued} for caching."
  end
end
