# frozen_string_literal: true

namespace :bands do
  desc "Queue enrichment for bands missing streaming links (prioritizes bands with reviews)"
  task :enrich, [:limit] => :environment do |_t, args|
    limit = (args[:limit] || 100).to_i

    # Prioritize bands that have reviews (users actually want to see these)
    bands_with_reviews = Band
      .joins(:reviews)
      .where(spotify_link: nil, apple_music_link: nil)
      .distinct
      .limit(limit)

    queued = 0
    bands_with_reviews.find_each do |band|
      BandEnrichmentJob.perform_later(band.id)
      queued += 1
    end

    puts "Queued #{queued} bands with reviews for enrichment"

    # If we haven't hit the limit, also queue some bands without reviews
    remaining = limit - queued
    if remaining > 0
      bands_without_reviews = Band
        .left_joins(:reviews)
        .where(reviews: { id: nil })
        .where(spotify_link: nil, apple_music_link: nil)
        .limit(remaining)

      bands_without_reviews.find_each do |band|
        BandEnrichmentJob.perform_later(band.id)
        queued += 1
      end

      puts "Queued #{remaining} additional bands without reviews"
    end

    puts "Total queued: #{queued}"
  end

  desc "Show band enrichment statistics"
  task stats: :environment do
    total = Band.count
    with_spotify = Band.where.not(spotify_link: nil).count
    with_apple = Band.where.not(apple_music_link: nil).count
    with_any_link = Band.where("spotify_link IS NOT NULL OR apple_music_link IS NOT NULL OR bandcamp_link IS NOT NULL OR youtube_music_link IS NOT NULL OR soundcloud_link IS NOT NULL").count
    with_mbid = Band.where.not(musicbrainz_id: nil).count

    bands_with_reviews = Band.joins(:reviews).distinct.count
    reviewed_with_links = Band.joins(:reviews).where("spotify_link IS NOT NULL OR apple_music_link IS NOT NULL").distinct.count

    puts "Band Enrichment Statistics"
    puts "=" * 40
    puts "Total bands: #{total}"
    puts "With MusicBrainz ID: #{with_mbid} (#{(with_mbid.to_f / total * 100).round(1)}%)"
    puts ""
    puts "Streaming Links:"
    puts "  Any link: #{with_any_link} (#{(with_any_link.to_f / total * 100).round(1)}%)"
    puts "  Spotify: #{with_spotify}"
    puts "  Apple Music: #{with_apple}"
    puts ""
    puts "Bands with reviews: #{bands_with_reviews}"
    puts "  With streaming links: #{reviewed_with_links} (#{(reviewed_with_links.to_f / bands_with_reviews * 100).round(1)}%)"
    puts "  Needing enrichment: #{bands_with_reviews - reviewed_with_links}"
  end

  desc "Enrich a single band by ID or name (for testing)"
  task :enrich_one, [:identifier] => :environment do |_t, args|
    identifier = args[:identifier]
    abort "Usage: rails bands:enrich_one[band_id_or_name]" if identifier.blank?

    band = Band.find_by(id: identifier) || Band.find_by("LOWER(name) = LOWER(?)", identifier)
    abort "Band not found: #{identifier}" unless band

    puts "Enriching band: #{band.name} (ID: #{band.id})"
    puts "  Current MusicBrainz ID: #{band.musicbrainz_id || 'none'}"
    puts "  Current Spotify: #{band.spotify_link || 'none'}"

    BandEnrichmentJob.perform_now(band.id)

    band.reload
    puts ""
    puts "After enrichment:"
    puts "  MusicBrainz ID: #{band.musicbrainz_id || 'none'}"
    puts "  Spotify: #{band.spotify_link || 'none'}"
    puts "  Apple Music: #{band.apple_music_link || 'none'}"
    puts "  Bandcamp: #{band.bandcamp_link || 'none'}"
    puts "  YouTube: #{band.youtube_music_link || 'none'}"
    puts "  SoundCloud: #{band.soundcloud_link || 'none'}"
    puts "  Genres: #{band.genres&.join(', ') || 'none'}"
    puts "  Country: #{band.country || 'none'}"
  end
end
