class BlogImage < ApplicationRecord
  belongs_to :user
  has_one_attached :image

  validates :user, presence: true
  validate :image_attached

  def image_url
    return nil unless image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      image,
      **active_storage_url_options
    )
  end

  private

  def active_storage_url_options
    if ENV['API_URL'].present?
      uri = URI.parse(ENV['API_URL'])
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
    else
      Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
    end
  end

  def image_attached
    errors.add(:image, 'must be attached') unless image.attached?
  end
end
