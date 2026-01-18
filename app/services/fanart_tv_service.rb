class FanartTvService
  include HTTParty
  base_uri 'https://webservice.fanart.tv/v3'

  class << self
    # Get artist images by MusicBrainz ID
    def get_artist_images(mbid)
      return nil if mbid.blank?
      return nil unless api_key.present?

      response = get("/music/#{mbid}", query: { api_key: api_key })

      return nil unless response.success?

      parse_artist_images(response.parsed_response)
    rescue StandardError => e
      Rails.logger.error("FanartTvService error: #{e.message}")
      nil
    end

    # Get the best artist thumbnail/image URL
    def get_artist_thumb(mbid)
      images = get_artist_images(mbid)
      return nil unless images

      # Priority: artistthumb > hdmusiclogo > musiclogo > artistbackground
      images[:thumbs]&.first ||
        images[:logos]&.first ||
        images[:backgrounds]&.first
    end

    private

    def api_key
      ENV['FANART_TV_API_KEY']
    end

    def parse_artist_images(data)
      return nil unless data.is_a?(Hash)

      {
        name: data['name'],
        mbid: data['mbid_id'],
        thumbs: extract_image_urls(data['artistthumb']),
        backgrounds: extract_image_urls(data['artistbackground']),
        logos: extract_image_urls(data['hdmusiclogo']) + extract_image_urls(data['musiclogo']),
        banners: extract_image_urls(data['musicbanner'])
      }
    end

    def extract_image_urls(images)
      return [] unless images.is_a?(Array)

      images.sort_by { |img| -img['likes'].to_i }
            .map { |img| img['url'] }
            .compact
    end
  end
end
