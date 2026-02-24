# frozen_string_literal: true

class BandEnrichmentJob < ApplicationJob
  queue_as :default

  # Retry on network errors with exponential backoff
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # Discard if the band no longer exists
  discard_on ActiveRecord::RecordNotFound

  def perform(band_id)
    band = Band.find(band_id)

    # Skip if already fully enriched (has streaming links)
    return if band.spotify_link.present? || band.apple_music_link.present?

    Rails.logger.info("BandEnrichmentJob: Enriching band #{band_id} '#{band.name}'")

    enrich_band(band)
  end

  private

  def enrich_band(band)
    # Try to get MusicBrainz data
    artist_data = fetch_artist_data(band)
    return unless artist_data

    Rails.logger.info("BandEnrichmentJob: Found MusicBrainz data for '#{band.name}'")

    updates = build_updates(band, artist_data)

    if updates.any?
      band.update!(updates)
      Rails.logger.info("BandEnrichmentJob: Updated band #{band.id} with: #{updates.keys.join(', ')}")
    end
  rescue StandardError => e
    Rails.logger.error("BandEnrichmentJob: Error enriching band #{band.id}: #{e.message}")
    raise # Let the retry mechanism handle it
  end

  def fetch_artist_data(band)
    # If we have a MusicBrainz ID, fetch directly
    if band.musicbrainz_id.present?
      return MusicbrainzService.get_artist(band.musicbrainz_id)
    end

    # Otherwise, search by name
    artist = MusicbrainzService.find_artist(band.name)
    return nil unless artist

    # Store the MBID for future lookups
    band.update!(musicbrainz_id: artist[:mbid]) if artist[:mbid].present?

    # Fetch full artist data
    MusicbrainzService.get_artist(artist[:mbid])
  end

  def build_updates(band, artist_data)
    updates = {}

    # Streaming links (only set if URL matches expected format)
    urls = artist_data[:urls] || {}
    updates[:spotify_link] = urls['spotify'] if band.spotify_link.blank? && valid_spotify_url?(urls['spotify'])
    updates[:apple_music_link] = urls['apple_music'] if band.apple_music_link.blank? && valid_apple_music_url?(urls['apple_music'])
    updates[:bandcamp_link] = urls['bandcamp'] if band.bandcamp_link.blank? && valid_bandcamp_url?(urls['bandcamp'])
    updates[:youtube_music_link] = urls['youtube'] if band.youtube_music_link.blank? && valid_youtube_music_url?(urls['youtube'])
    updates[:soundcloud_link] = urls['soundcloud'] if band.soundcloud_link.blank? && urls['soundcloud'].present?

    # Artist metadata
    updates[:sort_name] = artist_data[:sort_name] if band.sort_name.blank? && artist_data[:sort_name].present?
    updates[:artist_type] = artist_data[:type] if band.artist_type.blank? && artist_data[:type].present?
    updates[:country] = artist_data[:country] if band.country.blank? && artist_data[:country].present?
    updates[:genres] = artist_data[:genres]&.first(5) if band.genres.blank? && artist_data[:genres].present?

    # Artist image (if not already set)
    if band.artist_image_url.blank?
      image_url = fetch_artist_image(artist_data)
      updates[:artist_image_url] = image_url if image_url.present?
    end

    # Build bio from available data
    if band.about.blank?
      bio = build_artist_bio(artist_data)
      updates[:about] = bio if bio.present?
    end

    updates
  end

  def fetch_artist_image(artist_data)
    return nil unless artist_data[:mbid]

    # Try Fanart.tv if available
    if defined?(FanartTvService)
      image = FanartTvService.get_artist_thumb(artist_data[:mbid])
      return image if image.present?
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("BandEnrichmentJob: Failed to fetch artist image: #{e.message}")
    nil
  end

  def build_artist_bio(artist_data)
    parts = []
    parts << artist_data[:type] if artist_data[:type].present?

    location = [artist_data[:begin_area], artist_data[:country]].compact.join(', ')
    parts << "from #{location}" if location.present?

    genres = artist_data[:genres]&.first(3)
    parts << genres.join(', ') if genres.present?

    parts.any? ? parts.join(' · ') : nil
  end

  # URL validation helpers (must match Band model validations)
  def valid_spotify_url?(url)
    url.present? && url.match?(/\Ahttps:\/\/(open\.)?spotify\.com/)
  end

  def valid_apple_music_url?(url)
    url.present? && url.match?(/\Ahttps:\/\/music\.apple\.com/)
  end

  def valid_bandcamp_url?(url)
    url.present? && url.match?(/\Ahttps:\/\/[\w\-]+\.bandcamp\.com/)
  end

  def valid_youtube_music_url?(url)
    # MusicBrainz returns youtube.com URLs, not music.youtube.com
    # Only accept actual YouTube Music URLs
    url.present? && url.match?(/\Ahttps:\/\/music\.youtube\.com/)
  end
end
