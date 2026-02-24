# frozen_string_literal: true

class OdesliService
  include HTTParty
  base_uri 'https://api.song.link/v1-alpha.1'

  headers 'Accept' => 'application/json'

  # Rate limiting: 10 requests per minute = 6 seconds between requests
  RATE_LIMIT_DELAY = 6.0
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

  # Core platforms to store (ordered by popularity)
  CORE_PLATFORMS = %w[
    spotify
    appleMusic
    youtubeMusic
    tidal
    amazonMusic
    deezer
    soundcloud
    bandcamp
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

        options[:timeout] ||= 15
        get(path, options)
      rescue *NETWORK_ERRORS => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep_time = 2 ** (retries - 1)
          Rails.logger.warn("Odesli request failed (attempt #{retries}/#{MAX_RETRIES}): #{e.message}. Retrying in #{sleep_time}s...")
          sleep(sleep_time)
          retry
        else
          Rails.logger.error("Odesli request failed after #{MAX_RETRIES} retries: #{e.message}")
          raise
        end
      end
    end

    # Get streaming links by ISRC code
    # @param isrc [String] ISRC code (e.g., "USRC12345678")
    # @param country [String] Country code for localized links (default: "US")
    # @return [Hash, nil] Hash with :links and :page_url, or nil if not found
    def get_links_by_isrc(isrc, country: 'US')
      return nil if isrc.blank?

      Rails.logger.info("OdesliService: Looking up ISRC #{isrc}")

      response = rate_limited_get('/links', query: {
        platform: 'isrc',
        type: 'song',
        id: isrc,
        userCountry: country
      })

      return nil unless response.success?

      parse_response(response.parsed_response)
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("OdesliService network error for ISRC #{isrc}: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("OdesliService error for ISRC #{isrc}: #{e.message}")
      nil
    end

    # Get streaming links by URL from any supported platform
    # @param url [String] URL from any supported streaming platform
    # @param country [String] Country code for localized links (default: "US")
    # @return [Hash, nil] Hash with :links and :page_url, or nil if not found
    def get_links_by_url(url, country: 'US')
      return nil if url.blank?

      Rails.logger.info("OdesliService: Looking up URL #{url}")

      response = rate_limited_get('/links', query: {
        url: url,
        userCountry: country
      })

      return nil unless response.success?

      parse_response(response.parsed_response)
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("OdesliService network error for URL #{url}: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("OdesliService error for URL #{url}: #{e.message}")
      nil
    end

    private

    # Parse Odesli API response and extract relevant links
    # @param data [Hash] Parsed JSON response from Odesli API
    # @return [Hash, nil] Hash with :links and :page_url
    def parse_response(data)
      return nil unless data.is_a?(Hash)

      links_by_platform = data['linksByPlatform']
      return nil unless links_by_platform.is_a?(Hash)

      # Extract URLs for core platforms only
      links = {}
      CORE_PLATFORMS.each do |platform|
        platform_data = links_by_platform[platform]
        next unless platform_data.is_a?(Hash)

        url = platform_data['url']
        links[platform] = url if url.present?
      end

      return nil if links.empty?

      {
        links: links,
        page_url: data['pageUrl']
      }
    end
  end
end
