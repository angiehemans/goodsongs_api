class BlogImage < ApplicationRecord
  include ImageUrlHelper
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

  def image_attached
    errors.add(:image, 'must be attached') unless image.attached?
  end
end
