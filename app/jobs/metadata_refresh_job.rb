# frozen_string_literal: true

class MetadataRefreshJob < ApplicationJob
  queue_as :low

  # Retry on network errors
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # Batch size for processing
  BATCH_SIZE = 100

  def perform
    Rails.logger.info('MetadataRefreshJob: Starting daily metadata refresh')

    retry_not_found_scrobbles
    refresh_stale_metadata

    Rails.logger.info('MetadataRefreshJob: Completed daily metadata refresh')
  end

  private

  # Re-attempt enrichment for not_found scrobbles less than 7 days old
  def retry_not_found_scrobbles
    scrobbles = Scrobble
                .where(metadata_status: :not_found)
                .where('created_at > ?', 7.days.ago)
                .limit(BATCH_SIZE)

    count = scrobbles.count
    return if count.zero?

    Rails.logger.info("MetadataRefreshJob: Retrying #{count} not_found scrobbles")

    scrobbles.find_each do |scrobble|
      # Reset to pending so enrichment service will process it
      scrobble.update!(metadata_status: :pending)
      ScrobbleEnrichmentJob.perform_later(scrobble.id)
    end
  end

  # Refresh stale artist/album metadata (> 30 days since last update)
  def refresh_stale_metadata
    refresh_stale_artists
    refresh_stale_albums
  end

  def refresh_stale_artists
    stale_bands = Band
                    .where(user_id: nil)
                    .where('updated_at < ?', 30.days.ago)
                    .where.not(musicbrainz_id: nil)
                    .limit(BATCH_SIZE)

    count = stale_bands.count
    return if count.zero?

    Rails.logger.info("MetadataRefreshJob: Refreshing #{count} stale bands")

    stale_bands.find_each do |band|
      refresh_band(band)
    end
  end

  def refresh_stale_albums
    stale_albums = Album
                   .where('updated_at < ?', 30.days.ago)
                   .where.not(musicbrainz_release_id: nil)
                   .where(cover_art_url: nil)
                   .limit(BATCH_SIZE)

    count = stale_albums.count
    return if count.zero?

    Rails.logger.info("MetadataRefreshJob: Refreshing #{count} stale albums")

    stale_albums.find_each do |album|
      refresh_album(album)
    end
  end

  def refresh_band(band)
    artist_data = MusicbrainzService.get_artist(band.musicbrainz_id)
    return unless artist_data

    updates = {}

    # Try to get image if missing
    if band.artist_image_url.blank? && defined?(FanartTvService)
      image = FanartTvService.get_artist_thumb(band.musicbrainz_id)
      updates[:artist_image_url] = image if image.present?
    end

    # Update about if missing
    if band.about.blank?
      bio = build_artist_bio(artist_data)
      updates[:about] = bio if bio.present?
    end

    band.update!(updates) if updates.any?
  rescue StandardError => e
    Rails.logger.error("MetadataRefreshJob: Failed to refresh band #{band.id}: #{e.message}")
  end

  def refresh_album(album)
    # Try to fetch cover art
    cover_art_url = CoverArtArchiveService.get_cover_art_url(album.musicbrainz_release_id, size: 500)

    album.update!(cover_art_url: cover_art_url) if cover_art_url.present?
  rescue StandardError => e
    Rails.logger.error("MetadataRefreshJob: Failed to refresh album #{album.id}: #{e.message}")
  end

  def build_artist_bio(artist_data)
    parts = []
    parts << artist_data[:type] if artist_data[:type].present?

    location = [artist_data[:begin_area], artist_data[:country]].compact.join(', ')
    parts << "from #{location}" if location.present?

    genres = artist_data[:genres] || artist_data[:tags]&.first(3)
    parts << genres.join(', ') if genres.present?

    parts.any? ? parts.join(' · ') : nil
  end
end
