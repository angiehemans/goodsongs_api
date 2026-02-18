# frozen_string_literal: true

# Background job to download and cache external images to Active Storage
class CacheExternalImageJob < ApplicationJob
  queue_as :low_priority

  # Retry on network errors with exponential backoff
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # Don't retry if the record was deleted
  discard_on ActiveRecord::RecordNotFound

  # Maximum image size to download (10MB)
  MAX_IMAGE_SIZE = 10.megabytes

  # Allowed content types
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

  def perform(record_type:, record_id:, attribute:, url:, source:)
    record = record_type.constantize.find(record_id)
    attachment_name = "cached_#{attribute}"

    # Verify the record has this attachment
    unless record.respond_to?(attachment_name)
      Rails.logger.warn("CacheExternalImageJob: #{record_type} doesn't have #{attachment_name}")
      return
    end

    # Skip if already cached
    if record.send(attachment_name).attached?
      Rails.logger.info("CacheExternalImageJob: #{record_type}##{record_id} #{attribute} already cached")
      return
    end

    # Download the image
    image_data = download_image(url)
    return unless image_data

    # Attach to record
    filename = generate_filename(attribute, record_id, image_data[:content_type])
    record.send(attachment_name).attach(
      io: StringIO.new(image_data[:body]),
      filename: filename,
      content_type: image_data[:content_type]
    )

    # Update source and cached_at timestamp
    update_tracking_columns(record, attribute, source)

    Rails.logger.info("CacheExternalImageJob: Cached #{attribute} for #{record_type}##{record_id} from #{source}")
  end

  private

  def download_image(url)
    # Use HTTParty for HTTP requests with redirect following
    response = HTTParty.get(
      url,
      follow_redirects: true,
      timeout: 30,
      headers: { 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app)' }
    )

    unless response.success?
      Rails.logger.warn("CacheExternalImageJob: Failed to download #{url} - #{response.code}")
      return nil
    end

    content_type = response.content_type
    unless ALLOWED_CONTENT_TYPES.include?(content_type)
      Rails.logger.warn("CacheExternalImageJob: Invalid content type #{content_type} for #{url}")
      return nil
    end

    body = response.body
    if body.bytesize > MAX_IMAGE_SIZE
      Rails.logger.warn("CacheExternalImageJob: Image too large (#{body.bytesize} bytes) for #{url}")
      return nil
    end

    { body: body, content_type: content_type }
  rescue StandardError => e
    Rails.logger.error("CacheExternalImageJob: Error downloading #{url} - #{e.message}")
    raise # Let retry mechanism handle it
  end

  def generate_filename(attribute, record_id, content_type)
    extension = case content_type
                when 'image/jpeg' then 'jpg'
                when 'image/png' then 'png'
                when 'image/webp' then 'webp'
                when 'image/gif' then 'gif'
                else 'jpg'
                end

    "#{attribute}_#{record_id}.#{extension}"
  end

  def update_tracking_columns(record, attribute, source)
    updates = {}

    # Update source column if it exists
    source_column = "#{attribute}_source"
    if record.respond_to?("#{source_column}=")
      updates[source_column] = source
    end

    # Update cached_at column if it exists
    cached_at_column = "#{attribute}_cached_at"
    if record.respond_to?("#{cached_at_column}=")
      updates[cached_at_column] = Time.current
    end

    record.update_columns(updates) if updates.any?
  end
end
