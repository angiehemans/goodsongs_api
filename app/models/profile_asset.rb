class ProfileAsset < ApplicationRecord
  belongs_to :user
  has_one_attached :image

  PURPOSES = %w[background header custom].freeze
  MAX_ASSETS_PER_USER = 20
  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  validates :user, presence: true
  validates :purpose, inclusion: { in: PURPOSES, message: "must be one of: #{PURPOSES.join(', ')}" }
  validate :image_attached
  validate :image_content_type
  validate :image_file_size
  validate :assets_limit, on: :create

  def image_url
    return nil unless image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      image,
      **active_storage_url_options
    )
  end

  def thumbnail_url
    # Return main image URL as thumbnail (variant processing requires libvips)
    # TODO: Enable variants when libvips is installed: image.variant(resize_to_limit: [200, 200])
    image_url
  end

  def file_type
    return nil unless image.attached?
    image.content_type
  end

  def file_size
    return nil unless image.attached?
    image.byte_size
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

  def image_content_type
    return unless image.attached?
    unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
      errors.add(:image, "must be a JPEG, PNG, or WebP image")
    end
  end

  def image_file_size
    return unless image.attached?
    if image.byte_size > MAX_FILE_SIZE
      errors.add(:image, "must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end

  def assets_limit
    if user && user.profile_assets.count >= MAX_ASSETS_PER_USER
      errors.add(:base, "You can have a maximum of #{MAX_ASSETS_PER_USER} profile assets")
    end
  end
end
