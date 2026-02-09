# frozen_string_literal: true

module RecentlyPlayed
  # Provider that fetches recently played tracks from Last.fm API
  class LastfmProvider < BaseProvider
    def enabled?(user)
      user.lastfm_username.present?
    end

    def fetch(user, limit:)
      return [] unless enabled?(user)

      service = LastfmService.new(user)
      result = service.recently_played(limit: limit)

      return [] if result[:error]

      normalize_tracks(result[:tracks] || [])
    rescue StandardError => e
      Rails.logger.error("LastfmProvider error: #{e.message}")
      []
    end

    def source_name
      :lastfm
    end

    private

    def normalize_tracks(tracks)
      tracks.map do |track|
        normalize_track(
          track_name: track[:name],
          artist_name: extract_artist_name(track),
          album_name: track.dig(:album, :name),
          played_at: parse_played_at(track[:played_at]),
          now_playing: track[:now_playing] || false,
          mbid: track[:mbid],
          album_art_url: extract_album_art(track),
          loved: track[:loved] || false
        )
      end
    end

    def extract_artist_name(track)
      artists = track[:artists]
      return nil unless artists.is_a?(Array) && artists.any?

      artists.first[:name]
    end

    def extract_album_art(track)
      images = track.dig(:album, :images)
      return nil unless images.is_a?(Array) && images.any?

      # Prefer large or extralarge image
      large = images.find { |img| img[:size] == 'large' || img[:size] == 'extralarge' }
      (large || images.last)&.dig(:url)
    end

    def parse_played_at(played_at)
      return nil if played_at.nil?

      case played_at
      when Time, DateTime
        played_at.to_time
      when String
        Time.parse(played_at)
      when Integer
        Time.at(played_at)
      else
        nil
      end
    rescue ArgumentError
      nil
    end
  end
end
