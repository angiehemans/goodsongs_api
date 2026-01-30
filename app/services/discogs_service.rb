# frozen_string_literal: true

class DiscogsService
  include HTTParty
  base_uri 'https://api.discogs.com'

  # Discogs requires a User-Agent header
  headers 'User-Agent' => 'GoodSongs/1.0 +https://goodsongs.app'
  headers 'Accept' => 'application/json'

  # Rate limiting: 60 requests per minute for authenticated requests
  RATE_LIMIT_DELAY = 1.0  # 1 second between requests to be safe
  MAX_RETRIES = 3
  NETWORK_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    OpenSSL::SSL::SSLError,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Errno::ETIMEDOUT,
    SocketError
  ].freeze

  @rate_limit_mutex = Mutex.new
  @last_request_time = nil

  class << self
    # Rate-limited request wrapper with retry logic
    def rate_limited_get(path, options = {})
      retries = 0

      begin
        @rate_limit_mutex.synchronize do
          if @last_request_time
            elapsed = Time.current - @last_request_time
            sleep(RATE_LIMIT_DELAY - elapsed) if elapsed < RATE_LIMIT_DELAY
          end
          @last_request_time = Time.current
        end

        # Add authentication (key/secret method)
        options[:query] ||= {}
        options[:query][:key] = consumer_key if consumer_key.present?
        options[:query][:secret] = consumer_secret if consumer_secret.present?
        options[:timeout] ||= 10

        get(path, options)
      rescue *NETWORK_ERRORS => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep_time = 2 ** (retries - 1)
          Rails.logger.warn("Discogs request failed (attempt #{retries}/#{MAX_RETRIES}): #{e.message}. Retrying in #{sleep_time}s...")
          sleep(sleep_time)
          retry
        else
          Rails.logger.error("Discogs request failed after #{MAX_RETRIES} retries: #{e.message}")
          raise
        end
      end
    end

    # Search for releases by track and/or artist
    # Returns master releases (original versions) by default
    def search(track: nil, artist: nil, query: nil, type: 'master', limit: 10)
      return [] if track.blank? && artist.blank? && query.blank?

      search_params = {
        per_page: limit,
        page: 1
      }

      # Use type=master to get original releases, not reissues
      search_params[:type] = type if type.present?

      # Build search query
      if query.present?
        search_params[:q] = query
      else
        search_params[:track] = track if track.present?
        search_params[:artist] = artist if artist.present?
      end

      response = rate_limited_get('/database/search', query: search_params)

      return [] unless response.success?

      results = response.parsed_response['results']
      return [] unless results.is_a?(Array)

      results.map { |result| format_search_result(result) }
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("DiscogsService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("DiscogsService search error: #{e.message}")
      []
    end

    # Get detailed release/master info by ID
    def get_master(master_id)
      return nil if master_id.blank?

      response = rate_limited_get("/masters/#{master_id}")

      return nil unless response.success?

      format_master_detail(response.parsed_response)
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("DiscogsService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("DiscogsService get_master error: #{e.message}")
      nil
    end

    # Get release details (for tracklist)
    def get_release(release_id)
      return nil if release_id.blank?

      response = rate_limited_get("/releases/#{release_id}")

      return nil unless response.success?

      format_release_detail(response.parsed_response)
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("DiscogsService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("DiscogsService get_release error: #{e.message}")
      nil
    end

    # Search for artists
    def search_artist(query, limit: 10)
      return [] if query.blank?

      response = rate_limited_get('/database/search', query: {
        q: query,
        type: 'artist',
        per_page: limit,
        page: 1
      })

      return [] unless response.success?

      results = response.parsed_response['results']
      return [] unless results.is_a?(Array)

      results.map { |result| format_artist_result(result) }
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("DiscogsService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("DiscogsService search_artist error: #{e.message}")
      []
    end

    # Get artist discography
    def get_artist_releases(artist_id, limit: 20)
      return [] if artist_id.blank?

      response = rate_limited_get("/artists/#{artist_id}/releases", query: {
        sort: 'year',
        sort_order: 'desc',
        per_page: limit,
        page: 1
      })

      return [] unless response.success?

      releases = response.parsed_response['releases']
      return [] unless releases.is_a?(Array)

      # Filter to masters (original releases) and format
      releases.select { |r| r['type'] == 'master' }
              .map { |release| format_artist_release(release) }
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("DiscogsService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("DiscogsService get_artist_releases error: #{e.message}")
      []
    end

    private

    def consumer_key
      ENV.fetch('DISCOGS_CONSUMER_KEY', nil)
    end

    def consumer_secret
      ENV.fetch('DISCOGS_CONSUMER_SECRET', nil)
    end

    def format_search_result(result)
      # Extract artist name (remove numbers in parentheses like "Artist (2)")
      artist_name = result['title']&.split(' - ')&.first&.gsub(/\s*\(\d+\)\s*$/, '')
      release_title = result['title']&.split(' - ', 2)&.last

      {
        id: result['id'],
        master_id: result['master_id'],
        type: result['type'],
        title: release_title || result['title'],
        artist: artist_name,
        year: result['year'],
        country: result['country'],
        genre: result['genre']&.first,
        style: result['style']&.first,
        format: result['format']&.first,
        cover_image: result['cover_image'],
        thumb: result['thumb'],
        resource_url: result['resource_url']
      }
    end

    def format_master_detail(master)
      primary_artist = master['artists']&.first

      {
        id: master['id'],
        title: master['title'],
        artist: primary_artist&.dig('name')&.gsub(/\s*\(\d+\)\s*$/, ''),
        artist_id: primary_artist&.dig('id'),
        year: master['year'],
        genres: master['genres'] || [],
        styles: master['styles'] || [],
        tracklist: format_tracklist(master['tracklist']),
        images: master['images']&.map { |img| img['uri'] },
        cover_image: master['images']&.find { |img| img['type'] == 'primary' }&.dig('uri') ||
                     master['images']&.first&.dig('uri'),
        resource_url: master['resource_url'],
        main_release_id: master['main_release'],
        versions_count: master['versions_count']
      }
    end

    def format_release_detail(release)
      primary_artist = release['artists']&.first

      {
        id: release['id'],
        title: release['title'],
        artist: primary_artist&.dig('name')&.gsub(/\s*\(\d+\)\s*$/, ''),
        artist_id: primary_artist&.dig('id'),
        year: release['year'],
        country: release['country'],
        genres: release['genres'] || [],
        styles: release['styles'] || [],
        tracklist: format_tracklist(release['tracklist']),
        images: release['images']&.map { |img| img['uri'] },
        cover_image: release['images']&.find { |img| img['type'] == 'primary' }&.dig('uri') ||
                     release['images']&.first&.dig('uri'),
        resource_url: release['resource_url'],
        master_id: release['master_id']
      }
    end

    def format_tracklist(tracklist)
      return [] unless tracklist.is_a?(Array)

      tracklist.select { |t| t['type_'] == 'track' }
               .map do |track|
        {
          position: track['position'],
          title: track['title'],
          duration: track['duration'],
          artists: track['artists']&.map { |a| a['name']&.gsub(/\s*\(\d+\)\s*$/, '') }
        }
      end
    end

    def format_artist_result(result)
      {
        id: result['id'],
        name: result['title']&.gsub(/\s*\(\d+\)\s*$/, ''),
        thumb: result['thumb'],
        cover_image: result['cover_image'],
        resource_url: result['resource_url']
      }
    end

    def format_artist_release(release)
      {
        id: release['id'],
        master_id: release['main_release'],
        title: release['title'],
        year: release['year'],
        thumb: release['thumb'],
        resource_url: release['resource_url'],
        type: release['type'],
        role: release['role']
      }
    end
  end
end
