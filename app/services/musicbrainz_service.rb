class MusicbrainzService
  include HTTParty
  base_uri 'https://musicbrainz.org/ws/2'

  # MusicBrainz requires a User-Agent header identifying your application
  headers 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app; api@goodsongs.app)'
  headers 'Accept' => 'application/json'

  # Rate limiting: 1 request per second
  RATE_LIMIT_DELAY = 1.1
  @rate_limit_mutex = Mutex.new
  @last_request_time = nil

  class << self
    # Rate-limited request wrapper
    def rate_limited_get(path, options = {})
      @rate_limit_mutex.synchronize do
        if @last_request_time
          elapsed = Time.current - @last_request_time
          sleep(RATE_LIMIT_DELAY - elapsed) if elapsed < RATE_LIMIT_DELAY
        end
        @last_request_time = Time.current
      end

      get(path, options)
    end
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

    # Search for recordings by track name and artist name
    def search_recording(track_name, artist_name, limit: 5)
      return [] if track_name.blank? || artist_name.blank?

      # Build Lucene query for MusicBrainz
      query = "recording:\"#{escape_query(track_name)}\" AND artist:\"#{escape_query(artist_name)}\""

      response = rate_limited_get('/recording', query: {
        query: query,
        fmt: 'json',
        limit: limit
      })

      return [] unless response.success?

      recordings = response.parsed_response['recordings']
      return [] unless recordings.is_a?(Array)

      recordings.map { |recording| format_recording_search_result(recording) }
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error("MusicbrainzService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("MusicbrainzService search_recording error: #{e.message}")
      []
    end

    # Get detailed recording info by MBID
    def get_recording(mbid)
      return nil if mbid.blank?

      response = rate_limited_get("/recording/#{mbid}", query: {
        fmt: 'json',
        inc: 'artists+releases+isrcs'
      })

      return nil unless response.success?

      format_recording_detail(response.parsed_response)
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error("MusicbrainzService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("MusicbrainzService get_recording error: #{e.message}")
      nil
    end

    # Get detailed release (album) info by MBID
    def get_release(mbid)
      return nil if mbid.blank?

      response = rate_limited_get("/release/#{mbid}", query: {
        fmt: 'json',
        inc: 'artists+recordings+release-groups'
      })

      return nil unless response.success?

      format_release_detail(response.parsed_response)
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error("MusicbrainzService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("MusicbrainzService get_release error: #{e.message}")
      nil
    end

    # Search and get first matching recording with details
    def find_recording(track_name, artist_name)
      return nil if track_name.blank? || artist_name.blank?

      results = search_recording(track_name, artist_name, limit: 1)
      return nil if results.empty?

      mbid = results.first[:mbid]
      return results.first unless mbid

      get_recording(mbid) || results.first
    end

    private

    # Escape special Lucene query characters
    def escape_query(str)
      # Escape: + - && || ! ( ) { } [ ] ^ " ~ * ? : \ /
      str.gsub(/([+\-&|!(){}\[\]^"~*?:\\\/])/, '\\\\\1')
    end

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

    def format_recording_search_result(recording)
      {
        mbid: recording['id'],
        title: recording['title'],
        length: recording['length'], # duration in milliseconds
        score: recording['score'],
        artists: extract_artist_credits(recording['artist-credit']),
        releases: extract_releases(recording['releases']),
        first_release_date: recording.dig('first-release-date')
      }
    end

    def format_recording_detail(recording)
      {
        mbid: recording['id'],
        title: recording['title'],
        length: recording['length'],
        disambiguation: recording['disambiguation'],
        artists: extract_artist_credits(recording['artist-credit']),
        releases: extract_releases(recording['releases']),
        isrcs: recording['isrcs'] || [],
        first_release_date: recording.dig('first-release-date')
      }
    end

    def format_release_detail(release)
      {
        mbid: release['id'],
        title: release['title'],
        status: release['status'],
        date: release['date'],
        country: release['country'],
        barcode: release['barcode'],
        artists: extract_artist_credits(release['artist-credit']),
        release_group: extract_release_group(release['release-group']),
        track_count: release.dig('media', 0, 'track-count')
      }
    end

    def extract_artist_credits(credits)
      return [] unless credits.is_a?(Array)

      credits.map do |credit|
        artist = credit['artist']
        next unless artist

        {
          mbid: artist['id'],
          name: artist['name'],
          sort_name: artist['sort-name'],
          join_phrase: credit['joinphrase']
        }
      end.compact
    end

    def extract_releases(releases)
      return [] unless releases.is_a?(Array)

      releases.first(5).map do |release|
        {
          mbid: release['id'],
          title: release['title'],
          status: release['status'],
          date: release['date'],
          country: release['country'],
          release_group_mbid: release.dig('release-group', 'id')
        }
      end
    end

    def extract_release_group(release_group)
      return nil unless release_group

      {
        mbid: release_group['id'],
        title: release_group['title'],
        primary_type: release_group['primary-type'],
        secondary_types: release_group['secondary-types'] || []
      }
    end
  end
end
