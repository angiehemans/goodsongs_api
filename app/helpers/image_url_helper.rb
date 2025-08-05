module ImageUrlHelper
  def attachment_url(attachment)
    return nil unless attachment.attached?
    
    # Set default URL options if not already set
    Rails.application.routes.default_url_options[:host] ||= default_host
    
    Rails.application.routes.url_helpers.url_for(attachment)
  end

  def profile_image_url(resource)
    attachment_url(resource.profile_image)
  end

  def profile_picture_url(resource)
    attachment_url(resource.profile_picture)
  end

  private

  def default_host
    Rails.application.config.action_mailer.default_url_options[:host] || 
    ENV['HOST'] || 
    'localhost:3000'
  end
end