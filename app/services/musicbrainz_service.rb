class MusicbrainzService
  include HTTParty
  base_uri 'https://musicbrainz.org/ws/2'

  # MusicBrainz requires a User-Agent header identifying your application
  headers 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app)'
  headers 'Accept' => 'application/json'

  class << self
    # Search for artists by name
    def search_artist(query, limit: 10)
      return [] if query.blank?

      response = get('/artist', query: {
        query: "artist:#{query}",
        fmt: 'json',
        limit: limit
      })

      return [] unless response.success?

      artists = response.parsed_response['artists']
      return [] unless artists.is_a?(Array)

      artists.map { |artist| format_artist_search_result(artist) }
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      # Re-raise network errors so jobs can retry
      Rails.logger.error("MusicbrainzService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("MusicbrainzService search error: #{e.message}")
      []
    end

    # Get detailed artist info by MBID
    def get_artist(mbid)
      return nil if mbid.blank?

      response = get("/artist/#{mbid}", query: {
        fmt: 'json',
        inc: 'url-rels+tags+genres'
      })

      return nil unless response.success?

      format_artist_detail(response.parsed_response)
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      # Re-raise network errors so jobs can retry
      Rails.logger.error("MusicbrainzService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("MusicbrainzService get_artist error: #{e.message}")
      nil
    end

    # Search and get first matching artist with details
    def find_artist(name)
      return nil if name.blank?

      results = search_artist(name, limit: 1)
      return nil if results.empty?

      mbid = results.first[:mbid]
      return results.first unless mbid

      # Get full details
      get_artist(mbid) || results.first
    end

    private

    def format_artist_search_result(artist)
      {
        mbid: artist['id'],
        name: artist['name'],
        sort_name: artist['sort-name'],
        type: artist['type'], # Person, Group, Orchestra, Choir, Character, Other
        country: artist['country'],
        area: artist.dig('area', 'name'),
        disambiguation: artist['disambiguation'],
        score: artist['score'],
        tags: extract_tags(artist['tags']),
        begin_date: artist.dig('life-span', 'begin'),
        end_date: artist.dig('life-span', 'end'),
        ended: artist.dig('life-span', 'ended')
      }
    end

    def format_artist_detail(artist)
      {
        mbid: artist['id'],
        name: artist['name'],
        sort_name: artist['sort-name'],
        type: artist['type'],
        country: artist['country'],
        area: artist.dig('area', 'name'),
        begin_area: artist.dig('begin-area', 'name'),
        disambiguation: artist['disambiguation'],
        tags: extract_tags(artist['tags']),
        genres: extract_genres(artist['genres']),
        begin_date: artist.dig('life-span', 'begin'),
        end_date: artist.dig('life-span', 'end'),
        ended: artist.dig('life-span', 'ended'),
        urls: extract_urls(artist['relations'])
      }
    end

    def extract_tags(tags)
      return [] unless tags.is_a?(Array)
      tags.sort_by { |t| -t['count'].to_i }
          .first(10)
          .map { |t| t['name'] }
    end

    def extract_genres(genres)
      return [] unless genres.is_a?(Array)
      genres.sort_by { |g| -g['count'].to_i }
            .first(5)
            .map { |g| g['name'] }
    end

    def extract_urls(relations)
      return {} unless relations.is_a?(Array)

      url_types = %w[official homepage wikipedia wikidata discogs allmusic bandcamp soundcloud youtube]
      urls = {}

      relations.each do |rel|
        next unless rel['type'].present? && rel.dig('url', 'resource').present?

        type = rel['type'].downcase.gsub(/\s+/, '_')
        url = rel.dig('url', 'resource')

        # Standard URL types
        if url_types.include?(type) || type.include?('official')
          urls[type] = url
        end

        # Extract Spotify from "free streaming" relations
        if type == 'free_streaming' && url.include?('spotify.com')
          urls['spotify'] = url
        end

        # Extract Apple Music from "purchase for download" relations
        if type == 'purchase_for_download' && (url.include?('music.apple.com') || url.include?('itunes.apple.com'))
          # Convert iTunes URL to Apple Music format if needed
          urls['apple_music'] = url.gsub('itunes.apple.com', 'music.apple.com')
        end
      end

      urls
    end
  end
end
