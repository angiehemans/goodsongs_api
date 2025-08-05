module ImageSerializable
  extend ActiveSupport::Concern
  include ImageUrlHelper

  private

  def serialize_profile_image(resource)
    profile_image_url(resource)
  end

  def serialize_profile_picture(resource)
    profile_picture_url(resource)
  end
end