# frozen_string_literal: true

class ArtworkEnrichmentJob < ApplicationJob
  queue_as :low_priority

  # Retry on network errors with exponential backoff
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # Discard if the album no longer exists
  discard_on ActiveRecord::RecordNotFound

  def perform(album_id, user_id: nil)
    album = Album.find(album_id)

    # Skip if already has artwork
    return if album.cover_art_url.present?

    Rails.logger.info("ArtworkEnrichmentJob: Fetching artwork for album #{album_id} (#{album.name})")

    artwork_url = fetch_artwork_parallel(album)

    if artwork_url.present?
      album.update!(cover_art_url: artwork_url)
      Rails.logger.info("ArtworkEnrichmentJob: Successfully set artwork for album #{album_id}")

      # Invalidate user's scrobble cache if user_id provided
      ScrobbleCacheService.invalidate_recent_scrobbles(user_id) if user_id
    else
      Rails.logger.info("ArtworkEnrichmentJob: No artwork found for album #{album_id}")
    end
  end

  private

  def fetch_artwork_parallel(album)
    return nil unless album.name.present?

    artist_name = album.band&.name
    album_name = album.name
    release_mbid = album.musicbrainz_release_id

    results = Concurrent::Array.new
    threads = []

    # Source 1: TheAudioDB (preferred - returns official album artwork)
    if artist_name.present?
      threads << Thread.new do
        begin
          album_data = ScrobbleCacheService.get_audiodb_album(artist_name, album_name)
          if album_data
            url = album_data[:album_thumb_hq].presence || album_data[:album_thumb].presence
            results << { source: :audiodb, url: url, priority: 1 } if url.present?
          end
        rescue StandardError => e
          Rails.logger.debug("ArtworkEnrichmentJob: TheAudioDB failed: #{e.message}")
        end
      end
    end

    # Source 2: Cover Art Archive (if we have MusicBrainz ID)
    # Note: May return compilations/soundtracks, so lower priority than AudioDB
    if release_mbid.present?
      threads << Thread.new do
        begin
          url = ScrobbleCacheService.get_cover_art_url(release_mbid, size: 500)
          results << { source: :cover_art_archive, url: url, priority: 2 } if url.present?
        rescue StandardError => e
          Rails.logger.debug("ArtworkEnrichmentJob: Cover Art Archive failed: #{e.message}")
        end
      end
    end

    # Source 3: Discogs
    if artist_name.present?
      threads << Thread.new do
        begin
          url = ScrobbleCacheService.get_discogs_cover_art(album_name, artist_name)
          results << { source: :discogs, url: url, priority: 3 } if url.present?
        rescue StandardError => e
          Rails.logger.debug("ArtworkEnrichmentJob: Discogs failed: #{e.message}")
        end
      end
    end

    # Wait for all threads with timeout
    threads.each { |t| t.join(10) }

    # Return highest priority result (lowest priority number)
    best_result = results.min_by { |r| r[:priority] }

    if best_result
      Rails.logger.info("ArtworkEnrichmentJob: Found artwork from #{best_result[:source]} for '#{album_name}'")
      best_result[:url]
    else
      nil
    end
  end
end
