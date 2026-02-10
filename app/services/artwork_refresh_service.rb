# frozen_string_literal: true

# Service to refresh album artwork from multiple sources
# Used when artwork is missing or needs to be updated
class ArtworkRefreshService
  attr_reader :album, :track, :artist_name, :album_name, :track_name

  def initialize(album: nil, track: nil)
    @album = album
    @track = track

    if album
      @album_name = album.name
      @artist_name = album.band&.name
    elsif track
      @album = track.album
      @album_name = track.album&.name || track.name # Use track name as fallback for album search
      @artist_name = track.band&.name
      @track_name = track.name
    end
  end

  # Refresh artwork and return the new URL (or nil if not found)
  def refresh!
    return nil if artist_name.blank?

    artwork_url = fetch_artwork_from_all_sources

    if artwork_url.present? && album.present?
      album.update!(cover_art_url: artwork_url)
      Rails.logger.info("ArtworkRefreshService: Updated album #{album.id} (#{album.name}) with artwork from refresh")
    end

    artwork_url
  end

  # Check if artwork needs refreshing
  def needs_refresh?
    return true if album.nil?
    album.cover_art_url.blank?
  end

  private

  def fetch_artwork_from_all_sources
    # Try each source in priority order
    artwork_url = nil

    # 1. Cover Art Archive (if we have a MusicBrainz release ID)
    if album&.musicbrainz_release_id.present?
      artwork_url = fetch_from_cover_art_archive(album.musicbrainz_release_id)
      return artwork_url if artwork_url.present?
    end

    # 2. TheAudioDB
    artwork_url = fetch_from_audiodb
    return artwork_url if artwork_url.present?

    # 3. Discogs
    artwork_url = fetch_from_discogs
    return artwork_url if artwork_url.present?

    # 4. Last.fm
    artwork_url = fetch_from_lastfm
    return artwork_url if artwork_url.present?

    # 5. Try MusicBrainz search if we don't have a release ID
    artwork_url = fetch_from_musicbrainz_search
    return artwork_url if artwork_url.present?

    nil
  end

  def fetch_from_cover_art_archive(release_id)
    ScrobbleCacheService.get_cover_art_url(release_id, size: 500)
  rescue StandardError => e
    Rails.logger.warn("ArtworkRefreshService CAA error: #{e.message}")
    nil
  end

  def fetch_from_audiodb
    return nil if artist_name.blank?

    # Try album search first
    if album_name.present?
      album_data = ScrobbleCacheService.get_audiodb_album(artist_name, album_name)
      if album_data
        artwork = album_data[:album_thumb_hq].presence || album_data[:album_thumb].presence
        return artwork if artwork.present?
      end
    end

    # Try track search to find album
    if track_name.present?
      track_data = ScrobbleCacheService.get_audiodb_track(artist_name, track_name)
      if track_data && track_data[:album_id]
        album_data = AudioDbService.get_album(track_data[:album_id])
        if album_data
          artwork = album_data[:album_thumb_hq].presence || album_data[:album_thumb].presence
          return artwork if artwork.present?
        end
      end
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("ArtworkRefreshService AudioDB error: #{e.message}")
    nil
  end

  def fetch_from_discogs
    search_term = album_name.presence || track_name
    return nil if search_term.blank? || artist_name.blank?

    ScrobbleCacheService.get_discogs_cover_art(search_term, artist_name)
  rescue StandardError => e
    Rails.logger.warn("ArtworkRefreshService Discogs error: #{e.message}")
    nil
  end

  def fetch_from_lastfm
    return nil if artist_name.blank? || album_name.blank?

    album_info = LastfmService.get_album_info(artist: artist_name, album: album_name)
    return nil unless album_info && album_info[:image].present?

    find_largest_lastfm_image(album_info[:image])
  rescue StandardError => e
    Rails.logger.warn("ArtworkRefreshService Last.fm error: #{e.message}")
    nil
  end

  def fetch_from_musicbrainz_search
    search_term = track_name.presence || album_name
    return nil if search_term.blank? || artist_name.blank?

    recording = ScrobbleCacheService.get_musicbrainz_recording(search_term, artist_name)
    return nil unless recording && recording[:releases].present?

    # Try each release until we find artwork
    recording[:releases].first(5).each do |release|
      next unless release[:mbid]

      artwork_url = ScrobbleCacheService.get_cover_art_url(release[:mbid], size: 500)
      return artwork_url if artwork_url.present?
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("ArtworkRefreshService MusicBrainz error: #{e.message}")
    nil
  end

  def find_largest_lastfm_image(images)
    return nil unless images.is_a?(Array)

    size_priority = %w[mega extralarge large medium small]

    size_priority.each do |size|
      image = images.find { |img| img['size'] == size }
      url = image&.dig('#text')
      # Skip default placeholder image
      return url if url.present? && !url.include?('2a96cbd8b46e442fc41c2b86b821562f')
    end

    nil
  end

  class << self
    # Refresh artwork for a scrobble
    def refresh_for_scrobble(scrobble)
      return { status: 'no_track', message: 'Scrobble has no associated track' } unless scrobble.track

      service = new(track: scrobble.track)

      unless service.needs_refresh?
        return {
          status: 'already_has_artwork',
          artwork_url: scrobble.track.album&.cover_art_url
        }
      end

      artwork_url = service.refresh!

      if artwork_url.present?
        { status: 'success', artwork_url: artwork_url }
      else
        { status: 'not_found', message: 'Could not find artwork from any source' }
      end
    end

    # Refresh artwork for a track
    def refresh_for_track(track)
      service = new(track: track)

      unless service.needs_refresh?
        return {
          status: 'already_has_artwork',
          artwork_url: track.album&.cover_art_url
        }
      end

      artwork_url = service.refresh!

      if artwork_url.present?
        { status: 'success', artwork_url: artwork_url }
      else
        { status: 'not_found', message: 'Could not find artwork from any source' }
      end
    end

    # Refresh artwork for an album
    def refresh_for_album(album)
      service = new(album: album)

      unless service.needs_refresh?
        return {
          status: 'already_has_artwork',
          artwork_url: album.cover_art_url
        }
      end

      artwork_url = service.refresh!

      if artwork_url.present?
        { status: 'success', artwork_url: artwork_url }
      else
        { status: 'not_found', message: 'Could not find artwork from any source' }
      end
    end

    # Batch refresh for albums missing artwork
    def refresh_missing_artwork(limit: 50)
      albums = Album.where(cover_art_url: [nil, ''])
                    .includes(:band)
                    .limit(limit)

      results = { success: 0, not_found: 0, errors: 0 }

      albums.each do |album|
        result = refresh_for_album(album)
        case result[:status]
        when 'success'
          results[:success] += 1
        when 'not_found'
          results[:not_found] += 1
        else
          results[:errors] += 1
        end
      end

      results
    end
  end
end
