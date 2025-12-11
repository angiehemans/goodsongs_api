class SpotifyArtistService
  include HTTParty
  base_uri 'https://api.spotify.com/v1'

  class << self
    def fetch_artist_image(spotify_link)
      return nil if spotify_link.blank?

      artist_id = extract_artist_id(spotify_link)
      return nil unless artist_id

      artist_data = fetch_artist(artist_id)
      return nil unless artist_data

      # Get the largest image (first in array, typically 640x640)
      images = artist_data['images']
      return nil if images.blank?

      images.first['url']
    end

    def extract_artist_id(spotify_link)
      return nil if spotify_link.blank?

      # Handle various Spotify URL formats:
      # https://open.spotify.com/artist/1234abc
      # https://open.spotify.com/artist/1234abc?si=xxxxx
      # https://spotify.com/artist/1234abc
      match = spotify_link.match(%r{spotify\.com/artist/([a-zA-Z0-9]+)})
      match&.[](1)
    end

    private

    def fetch_artist(artist_id)
      token = access_token
      return nil unless token

      response = get(
        "/artists/#{artist_id}",
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        }
      )

      response.success? ? response.parsed_response : nil
    rescue StandardError => e
      Rails.logger.error("SpotifyArtistService error fetching artist: #{e.message}")
      nil
    end

    def access_token
      # Use cached token if available and not expired
      @token_expires_at ||= Time.at(0)

      if @cached_token && Time.current < @token_expires_at
        return @cached_token
      end

      # Request new token using Client Credentials flow
      response = HTTParty.post(
        'https://accounts.spotify.com/api/token',
        body: {
          grant_type: 'client_credentials',
          client_id: ENV['SPOTIFY_CLIENT_ID'],
          client_secret: ENV['SPOTIFY_CLIENT_SECRET']
        },
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )

      if response.success?
        @cached_token = response['access_token']
        expires_in = response['expires_in'] || 3600
        # Expire 60 seconds early to avoid edge cases
        @token_expires_at = Time.current + expires_in.seconds - 60.seconds
        @cached_token
      else
        Rails.logger.error("SpotifyArtistService failed to get access token: #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("SpotifyArtistService error getting access token: #{e.message}")
      nil
    end
  end
end
