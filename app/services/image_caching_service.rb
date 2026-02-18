# frozen_string_literal: true

# Service for caching external images to Active Storage
# Only caches from approved sources (Cover Art Archive, AudioDB)
# Excludes Last.fm (100MB limit) and Discogs (6-hour freshness requirement)
class ImageCachingService
  # Sources that are safe to cache without restrictions
  CACHEABLE_SOURCES = %w[coverartarchive audiodb wikidata wikipedia wikimedia].freeze

  class << self
    # Queue an image for caching
    def cache_image(record:, attribute:, url:, source:)
      return if url.blank?
      return unless cacheable_source?(source)

      CacheExternalImageJob.perform_later(
        record_type: record.class.name,
        record_id: record.id,
        attribute: attribute.to_s,
        url: url,
        source: source.to_s
      )
    end

    # Resolve the best image URL (cached or external)
    # Returns cached URL if available, otherwise queues caching and returns external URL
    def resolve_image_url(record:, cached_attachment:, external_url:, source:)
      # If we have a cached version, use it
      if cached_attachment&.attached?
        return rails_blob_url(cached_attachment, record)
      end

      # No cache - trigger caching for eligible sources
      if external_url.present? && cacheable_source?(source)
        cache_image(
          record: record,
          attribute: cached_attachment.name,
          url: external_url,
          source: source
        )
      end

      # Return external URL for now
      external_url
    end

    # Check if a source is eligible for caching
    def cacheable_source?(source)
      return false if source.blank?
      CACHEABLE_SOURCES.include?(source.to_s.downcase)
    end

    # Determine the source from a URL
    def detect_source(url)
      return nil if url.blank?

      case url
      when /coverartarchive\.org/i
        'coverartarchive'
      when /theaudiodb\.com/i
        'audiodb'
      when /wikidata\.org/i
        'wikidata'
      when /wikipedia\.org/i
        'wikipedia'
      when /wikimedia\.org/i, /commons\.wikimedia\.org/i
        'wikimedia'
      else
        'unknown'
      end
    end

    private

    def rails_blob_url(attachment, record)
      return nil unless attachment.attached?

      Rails.application.routes.url_helpers.rails_blob_url(
        attachment,
        **active_storage_url_options
      )
    end

    def active_storage_url_options
      if ENV['API_URL'].present?
        uri = URI.parse(ENV['API_URL'])
        port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
        { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
      else
        Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
      end
    end
  end
end
