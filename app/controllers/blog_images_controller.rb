class BlogImagesController < ApplicationController
  include ResourceController

  before_action :authenticate_request

  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

  # POST /blog_images
  def create
    require_ability!(:attach_images) and return if performed?

    unless params[:image].present?
      return json_response({ error: 'No image provided' }, :unprocessable_entity)
    end

    image = params[:image]

    # Validate content type
    unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
      return json_response({
        error: 'Invalid file type. Allowed: JPEG, PNG, WebP, GIF'
      }, :unprocessable_entity)
    end

    # Validate file size
    if image.size > MAX_FILE_SIZE
      return json_response({
        error: "File too large. Maximum size: #{MAX_FILE_SIZE / 1.megabyte}MB"
      }, :unprocessable_entity)
    end

    # Create a BlogImage record to hold the attachment
    blog_image = current_user.blog_images.build
    blog_image.image.attach(image)

    if blog_image.save
      json_response({
        id: blog_image.id,
        url: blog_image.image_url,
        filename: image.original_filename,
        content_type: image.content_type,
        byte_size: image.size
      }, :created)
    else
      render_errors(blog_image)
    end
  end
end
