# frozen_string_literal: true

class ScrobbleCacheService
  RECENT_SCROBBLES_TTL = 60.seconds
  MUSICBRAINZ_CACHE_TTL = 24.hours
  COVER_ART_CACHE_TTL = 24.hours

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
  end
end
