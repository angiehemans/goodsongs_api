# frozen_string_literal: true

class ScrobbleCacheService
  RECENT_SCROBBLES_TTL = 60.seconds
  MUSICBRAINZ_CACHE_TTL = 24.hours
  COVER_ART_CACHE_TTL = 24.hours
  DISCOGS_CACHE_TTL = 24.hours

  class << self
    # Cache key for user's recent scrobbles
    def recent_scrobbles_key(user_id, limit)
      "scrobbles:recent:#{user_id}:#{limit}"
    end

    # Get cached recent scrobbles or fetch from database
    def get_recent_scrobbles(user, limit:)
      cache_key = recent_scrobbles_key(user.id, limit)

      Rails.cache.fetch(cache_key, expires_in: RECENT_SCROBBLES_TTL) do
        user.scrobbles.recent.limit(limit).includes(track: [:band, :album]).to_a
      end
    end

    # Invalidate user's recent scrobbles cache
    def invalidate_recent_scrobbles(user_id)
      # Invalidate common limit values
      [10, 20, 50].each do |limit|
        Rails.cache.delete(recent_scrobbles_key(user_id, limit))
      end
    end

    # Cache key for MusicBrainz recording search
    def musicbrainz_recording_key(track_name, artist_name)
      normalized_key = "#{track_name.downcase.strip}:#{artist_name.downcase.strip}"
      "musicbrainz:recording:#{Digest::SHA256.hexdigest(normalized_key)}"
    end

    # Get cached MusicBrainz recording or fetch from API
    def get_musicbrainz_recording(track_name, artist_name)
      cache_key = musicbrainz_recording_key(track_name, artist_name)

      Rails.cache.fetch(cache_key, expires_in: MUSICBRAINZ_CACHE_TTL) do
        MusicbrainzService.find_recording(track_name, artist_name)
      end
    end

    # Cache key for cover art
    def cover_art_key(release_mbid)
      "coverart:#{release_mbid}"
    end

    # Get cached cover art URL or fetch from API
    def get_cover_art_url(release_mbid, size: 500)
      cache_key = cover_art_key(release_mbid)

      Rails.cache.fetch(cache_key, expires_in: COVER_ART_CACHE_TTL) do
        CoverArtArchiveService.get_cover_art_url(release_mbid, size: size)
      end
    end

    # Cache key for MusicBrainz search results
    def search_results_key(track_name, artist_name, limit)
      normalized_key = "#{track_name.downcase.strip}:#{artist_name&.downcase&.strip}:#{limit}"
      "musicbrainz:search:#{Digest::SHA256.hexdigest(normalized_key)}"
    end

    # Get cached search results or fetch from API
    def get_search_results(track_name, artist_name, limit: 5)
      cache_key = search_results_key(track_name, artist_name, limit)

      Rails.cache.fetch(cache_key, expires_in: MUSICBRAINZ_CACHE_TTL) do
        MusicbrainzService.search_recording(track_name, artist_name, limit: limit)
      end
    end

    # Cache key for recording detail
    def recording_detail_key(mbid)
      "musicbrainz:recording_detail:#{mbid}"
    end

    # Get cached recording detail or fetch from API
    def get_recording_detail(mbid)
      cache_key = recording_detail_key(mbid)

      Rails.cache.fetch(cache_key, expires_in: MUSICBRAINZ_CACHE_TTL) do
        MusicbrainzService.get_recording(mbid)
      end
    end

    # Cache key for Discogs search results
    def discogs_search_key(track_name, artist_name)
      normalized_key = "#{track_name.downcase.strip}:#{artist_name.downcase.strip}"
      "discogs:search:#{Digest::SHA256.hexdigest(normalized_key)}"
    end

    # Get cached Discogs search results or fetch from API
    def get_discogs_search(track_name, artist_name)
      cache_key = discogs_search_key(track_name, artist_name)

      Rails.cache.fetch(cache_key, expires_in: DISCOGS_CACHE_TTL) do
        DiscogsService.search(track: track_name, artist: artist_name, limit: 5)
      end
    end

    # Cache key for Discogs master release
    def discogs_master_key(master_id)
      "discogs:master:#{master_id}"
    end

    # Get cached Discogs master release or fetch from API
    def get_discogs_master(master_id)
      cache_key = discogs_master_key(master_id)

      Rails.cache.fetch(cache_key, expires_in: DISCOGS_CACHE_TTL) do
        DiscogsService.get_master(master_id)
      end
    end

    # Cache key for Discogs release
    def discogs_release_key(release_id)
      "discogs:release:#{release_id}"
    end

    # Get cached Discogs release or fetch from API
    def get_discogs_release(release_id)
      cache_key = discogs_release_key(release_id)

      Rails.cache.fetch(cache_key, expires_in: DISCOGS_CACHE_TTL) do
        DiscogsService.get_release(release_id)
      end
    end

    # Cache key for Discogs cover art lookup
    def discogs_cover_art_key(album_name, artist_name)
      normalized_key = "#{album_name.downcase.strip}:#{artist_name.downcase.strip}"
      "discogs:coverart:#{Digest::SHA256.hexdigest(normalized_key)}"
    end

    # Get cached Discogs cover art URL or fetch from API
    def get_discogs_cover_art(album_name, artist_name)
      cache_key = discogs_cover_art_key(album_name, artist_name)

      Rails.cache.fetch(cache_key, expires_in: COVER_ART_CACHE_TTL) do
        fetch_discogs_cover_art_uncached(album_name, artist_name)
      end
    end

    # Fetch cover art from Discogs (not cached - called by get_discogs_cover_art)
    def fetch_discogs_cover_art_uncached(album_name, artist_name)
      # Search for the album
      results = get_discogs_search(album_name, artist_name)
      return nil if results.blank?

      # Find a result with cover art
      results.each do |result|
        cover_image = result[:cover_image]
        next if cover_image.blank? || cover_image.include?('spacer.gif')
        return cover_image
      end

      # Try master release
      master_id = results.first[:master_id] || results.first[:id]
      if master_id
        master = get_discogs_master(master_id)
        if master && master[:cover_image].present? && !master[:cover_image].include?('spacer.gif')
          return master[:cover_image]
        end
      end

      nil
    end

    # ============================================
    # TheAudioDB Caching
    # ============================================

    AUDIODB_CACHE_TTL = 24.hours

    # Cache key for AudioDB artist search
    def audiodb_artist_key(artist_name)
      "audiodb:artist:#{Digest::SHA256.hexdigest(artist_name.downcase.strip)}"
    end

    # Get cached AudioDB artist or fetch from API
    def get_audiodb_artist(artist_name)
      cache_key = audiodb_artist_key(artist_name)

      Rails.cache.fetch(cache_key, expires_in: AUDIODB_CACHE_TTL) do
        AudioDbService.search_artist(artist_name)
      end
    end

    # Cache key for AudioDB album search
    def audiodb_album_key(artist_name, album_name)
      normalized_key = "#{artist_name.downcase.strip}:#{album_name.downcase.strip}"
      "audiodb:album:#{Digest::SHA256.hexdigest(normalized_key)}"
    end

    # Get cached AudioDB album or fetch from API
    def get_audiodb_album(artist_name, album_name)
      cache_key = audiodb_album_key(artist_name, album_name)

      Rails.cache.fetch(cache_key, expires_in: AUDIODB_CACHE_TTL) do
        AudioDbService.search_album(artist: artist_name, album: album_name)
      end
    end

    # Cache key for AudioDB track search
    def audiodb_track_key(artist_name, track_name)
      normalized_key = "#{artist_name.downcase.strip}:#{track_name.downcase.strip}"
      "audiodb:track:#{Digest::SHA256.hexdigest(normalized_key)}"
    end

    # Get cached AudioDB track or fetch from API
    def get_audiodb_track(artist_name, track_name)
      cache_key = audiodb_track_key(artist_name, track_name)

      Rails.cache.fetch(cache_key, expires_in: AUDIODB_CACHE_TTL) do
        AudioDbService.search_track(artist: artist_name, track: track_name)
      end
    end

    # Cache key for AudioDB artist by MusicBrainz ID
    def audiodb_artist_mbid_key(mbid)
      "audiodb:artist_mbid:#{mbid}"
    end

    # Get cached AudioDB artist by MusicBrainz ID or fetch from API
    def get_audiodb_artist_by_mbid(mbid)
      cache_key = audiodb_artist_mbid_key(mbid)

      Rails.cache.fetch(cache_key, expires_in: AUDIODB_CACHE_TTL) do
        AudioDbService.get_artist_by_mbid(mbid)
      end
    end
  end
end
