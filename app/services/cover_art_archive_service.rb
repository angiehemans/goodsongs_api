# frozen_string_literal: true

class CoverArtArchiveService
  include HTTParty
  base_uri 'https://coverartarchive.org'

  headers 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app; api@goodsongs.app)'

  class << self
    # Get cover art URL for a release by MBID
    # Returns the final URL after following redirects
    def get_cover_art_url(release_mbid, size: 500)
      return nil if release_mbid.blank?

      # Cover Art Archive returns a 307 redirect to the actual image
      # We need to follow the redirect to get the final URL
      size_suffix = case size
                    when 250 then '-250'
                    when 500 then '-500'
                    when 1200 then '-1200'
                    else ''
                    end

      response = head("/release/#{release_mbid}/front#{size_suffix}",
                      follow_redirects: false)

      if response.code == 307
        # Return the redirect location (the actual image URL)
        response.headers['location']
      elsif response.code == 200
        # Sometimes the API returns the image directly
        "#{base_uri}/release/#{release_mbid}/front#{size_suffix}"
      else
        nil
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error("CoverArtArchiveService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("CoverArtArchiveService error: #{e.message}")
      nil
    end

    # Get all cover art images for a release
    def get_release_images(release_mbid)
      return nil if release_mbid.blank?

      response = get("/release/#{release_mbid}")

      return nil unless response.success?

      images = response.parsed_response['images']
      return nil unless images.is_a?(Array)

      images.map do |image|
        {
          id: image['id'],
          front: image['front'],
          back: image['back'],
          types: image['types'],
          image: image['image'],
          thumbnails: {
            small: image.dig('thumbnails', 'small'),
            large: image.dig('thumbnails', 'large'),
            '250' => image.dig('thumbnails', '250'),
            '500' => image.dig('thumbnails', '500'),
            '1200' => image.dig('thumbnails', '1200')
          }
        }
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error("CoverArtArchiveService network error: #{e.message}")
      raise
    rescue StandardError => e
      Rails.logger.error("CoverArtArchiveService error: #{e.message}")
      nil
    end

    # Get the front cover image URL (most common use case)
    # Returns the 500px version by default
    def get_front_cover(release_mbid, size: 500)
      return nil if release_mbid.blank?

      images = get_release_images(release_mbid)
      return nil unless images

      front_image = images.find { |img| img[:front] }
      return nil unless front_image

      # Return appropriate size thumbnail
      case size
      when 250
        front_image.dig(:thumbnails, '250') || front_image.dig(:thumbnails, :small)
      when 500
        front_image.dig(:thumbnails, '500') || front_image.dig(:thumbnails, :large)
      when 1200
        front_image.dig(:thumbnails, '1200') || front_image[:image]
      else
        front_image[:image]
      end
    end

    # Quick check if cover art exists for a release
    def has_cover_art?(release_mbid)
      return false if release_mbid.blank?

      response = head("/release/#{release_mbid}", follow_redirects: false)
      response.code == 200 || response.code == 307
    rescue StandardError
      false
    end
  end
end
