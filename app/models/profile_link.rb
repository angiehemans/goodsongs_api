class ProfileLink < ApplicationRecord
  include ImageUrlHelper
  belongs_to :user
  has_one_attached :thumbnail

  MAX_FILE_SIZE = 2.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 200 }, allow_blank: true
  validates :url, presence: true, format: { with: /\Ahttps?:\/\/.+/i, message: "must be a valid URL" }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :thumbnail_content_type
  validate :thumbnail_file_size

  scope :ordered, -> { order(:position) }
  scope :visible, -> { where(visible: true) }

  def thumbnail_url
    return nil unless thumbnail.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      thumbnail,
      **active_storage_url_options
    )
  end

  private

  def thumbnail_content_type
    return unless thumbnail.attached?
    unless ALLOWED_CONTENT_TYPES.include?(thumbnail.content_type)
      errors.add(:thumbnail, "must be a JPEG, PNG, or WebP image")
    end
  end

  def thumbnail_file_size
    return unless thumbnail.attached?
    if thumbnail.byte_size > MAX_FILE_SIZE
      errors.add(:thumbnail, "must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end
end
