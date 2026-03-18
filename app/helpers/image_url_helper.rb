module ImageUrlHelper
  # Shared URL options for generating absolute Active Storage blob URLs.
  # Used by models, controllers, and services via `**ImageUrlHelper.active_storage_url_options`.
  def self.active_storage_url_options
    if ENV['API_URL'].present?
      uri = URI.parse(ENV['API_URL'])
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
    else
      Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
    end
  end

  # Instance-level delegate for use in classes that include this module
  def active_storage_url_options
    ImageUrlHelper.active_storage_url_options
  end

  def attachment_url(attachment)
    return nil unless attachment.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      attachment,
      **ImageUrlHelper.active_storage_url_options
    )
  end

  def profile_image_url(resource)
    attachment_url(resource.profile_image)
  end

  def profile_picture_url(resource)
    attachment_url(resource.profile_picture)
  end

  # For feed author avatars: band-role users show their band's image, others show user profile image
  def author_avatar_url(user)
    if user.band? && user.primary_band
      profile_picture_url(user.primary_band) || user.primary_band.resolved_artist_image_url
    else
      profile_image_url(user)
    end
  end
end