# frozen_string_literal: true

module RecentlyPlayed
  # Base class for recently played track providers.
  # Each provider fetches tracks from a different source (Last.fm, DB scrobbles, etc.)
  # and normalizes them to a common format for aggregation.
  class BaseProvider
    # Check if this provider is enabled/connected for the given user
    # @param user [User] the user to check
    # @return [Boolean] true if provider can fetch tracks for this user
    def enabled?(user)
      raise NotImplementedError, "#{self.class} must implement #enabled?"
    end

    # Fetch recently played tracks from this source
    # @param user [User] the user to fetch tracks for
    # @param limit [Integer] maximum number of tracks to fetch
    # @return [Array<Hash>] array of normalized track hashes
    def fetch(user, limit:)
      raise NotImplementedError, "#{self.class} must implement #fetch"
    end

    # Unique identifier for this source
    # @return [Symbol] source name (e.g., :lastfm, :scrobble, :apple_music)
    def source_name
      raise NotImplementedError, "#{self.class} must implement #source_name"
    end

    protected

    # Normalize a track to the common format used by RecentlyPlayedService
    # @param attrs [Hash] track attributes
    # @return [Hash] normalized track hash
    def normalize_track(attrs)
      {
        track_name: attrs[:track_name],
        artist_name: attrs[:artist_name],
        album_name: attrs[:album_name],
        played_at: attrs[:played_at],
        now_playing: attrs[:now_playing] || false,
        source: source_name,
        mbid: attrs[:mbid],
        album_art_url: attrs[:album_art_url],
        loved: attrs[:loved] || false
      }
    end
  end
end
