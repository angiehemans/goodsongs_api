class LastfmArtistService
  include HTTParty
  base_uri 'https://ws.audioscrobbler.com/2.0'

  class << self
    def fetch_artist_image(artist_identifier)
      return nil if artist_identifier.blank?

      artist_name = extract_artist_name(artist_identifier)
      return nil unless artist_name

      artist_data = fetch_artist(artist_name)
      return nil unless artist_data

      images = artist_data['image']
      return nil if images.blank?

      # Get the largest image (prefer extralarge or mega)
      largest_image = find_largest_image(images)
      largest_image.presence
    end

    def search_artist(query, limit: 10)
      return [] if query.blank?

      response = get('/', query: {
        method: 'artist.search',
        artist: query,
        api_key: api_key,
        format: 'json',
        limit: limit
      })

      return [] unless response.success?

      artists = response.parsed_response.dig('results', 'artistmatches', 'artist')
      return [] unless artists.is_a?(Array)

      artists.map do |artist|
        {
          name: artist['name'],
          mbid: artist['mbid'].presence,
          url: artist['url'],
          listeners: artist['listeners'].to_i,
          image_url: find_largest_image(artist['image'])
        }
      end
    rescue StandardError => e
      Rails.logger.error("LastfmArtistService search error: #{e.message}")
      []
    end

    def extract_artist_name(identifier)
      return nil if identifier.blank?

      # Handle Last.fm URL format:
      # https://www.last.fm/music/Artist+Name
      # https://last.fm/music/Artist+Name
      if identifier.match?(%r{last\.fm/music/})
        match = identifier.match(%r{last\.fm/music/([^/?\s]+)})
        return URI.decode_www_form_component(match[1]) if match
      end

      # If not a URL, treat as artist name
      identifier.strip
    end

    private

    def fetch_artist(artist_name)
      response = get('/', query: {
        method: 'artist.getInfo',
        artist: artist_name,
        api_key: api_key,
        format: 'json',
        autocorrect: 1
      })

      return nil unless response.success?

      response.parsed_response['artist']
    rescue StandardError => e
      Rails.logger.error("LastfmArtistService error fetching artist: #{e.message}")
      nil
    end

    def find_largest_image(images)
      return nil unless images.is_a?(Array)

      # Priority order for image sizes
      size_priority = %w[mega extralarge large medium small]

      size_priority.each do |size|
        image = images.find { |img| img['size'] == size }
        url = image&.dig('#text')
        return url if url.present?
      end

      # Fallback to any available image
      images.find { |img| img['#text'].present? }&.dig('#text')
    end

    def api_key
      ENV['LASTFM_API_KEY']
    end
  end
end
