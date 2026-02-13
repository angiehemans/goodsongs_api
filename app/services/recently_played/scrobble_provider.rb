# frozen_string_literal: true

module RecentlyPlayed
  # Provider that fetches recently played tracks from the Scrobbles table
  class ScrobbleProvider < BaseProvider
    def enabled?(user)
      # Scrobble provider is always enabled - users can always have local scrobbles
      true
    end

    def fetch(user, limit:)
      scrobbles = ScrobbleCacheService.get_recent_scrobbles(user, limit: limit)
      normalize_scrobbles(scrobbles)
    rescue StandardError => e
      Rails.logger.error("ScrobbleProvider error: #{e.message}")
      []
    end

    def source_name
      :scrobble
    end

    private

    def normalize_scrobbles(scrobbles)
      scrobbles.map do |scrobble|
        normalize_track(
          track_name: scrobble.track_name,
          artist_name: scrobble.artist_name,
          album_name: scrobble.album_name,
          played_at: scrobble.played_at,
          now_playing: false,
          mbid: scrobble.musicbrainz_recording_id,
          album_art_url: scrobble.effective_artwork_url,
          loved: false,
          scrobble_id: scrobble.id,
          metadata_status: scrobble.metadata_status,
          can_refresh_artwork: scrobble.track.present?,
          has_preferred_artwork: scrobble.has_preferred_artwork?
        )
      end
    end
  end
end
