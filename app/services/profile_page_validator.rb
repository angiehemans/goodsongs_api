# frozen_string_literal: true

class ProfilePageValidator
  PAGE_TYPES = %w[links].freeze
  LINK_PAGE_LAYOUTS = %w[list grid].freeze

  attr_reader :errors

  def initialize(pages)
    @pages = pages
    @errors = []
  end

  def valid?
    @errors = []

    validate_array_format
    return false if @errors.any?

    validate_pages
    @errors.empty?
  end

  def error_messages
    @errors.join(', ')
  end

  private

  def validate_array_format
    unless @pages.is_a?(Array) || @pages.respond_to?(:each_with_index)
      @errors << "Pages must be an array"
    end
  end

  def validate_pages
    seen_types = {}

    @pages.each_with_index do |page, index|
      unless page.is_a?(Hash) || page.is_a?(ActionController::Parameters)
        @errors << "Page at index #{index} must be an object"
        next
      end

      type = page['type'] || page[:type]
      slug = page['slug'] || page[:slug]
      visible = page['visible'] || page[:visible]

      unless PAGE_TYPES.include?(type)
        @errors << "Invalid page type '#{type}' at index #{index}"
      end

      if slug.blank?
        @errors << "Page at index #{index} missing 'slug' field"
      end

      unless [true, false].include?(visible)
        @errors << "Page at index #{index} 'visible' must be a boolean"
      end

      # Each page type can only appear once
      if type && seen_types[type]
        @errors << "Page type '#{type}' can only appear once"
      end
      seen_types[type] = true

      # Validate type-specific settings
      validate_links_settings(page, index) if type == 'links'
    end
  end

  def validate_links_settings(page, index)
    settings = page['settings'] || page[:settings] || {}
    return if settings.blank?

    heading = settings['heading'] || settings[:heading]
    if heading.is_a?(String) && heading.length > 120
      @errors << "Links page heading exceeds 120 characters (page #{index})"
    end

    description = settings['description'] || settings[:description]
    if description.is_a?(String) && description.length > 500
      @errors << "Links page description exceeds 500 characters (page #{index})"
    end

    show_social = settings['show_social_links'] || settings[:show_social_links]
    if !show_social.nil? && ![true, false].include?(show_social)
      @errors << "Links page show_social_links must be a boolean (page #{index})"
    end

    show_streaming = settings['show_streaming_links'] || settings[:show_streaming_links]
    if !show_streaming.nil? && ![true, false].include?(show_streaming)
      @errors << "Links page show_streaming_links must be a boolean (page #{index})"
    end

    layout = settings['layout'] || settings[:layout]
    if layout.present? && !LINK_PAGE_LAYOUTS.include?(layout)
      @errors << "Links page layout must be one of: #{LINK_PAGE_LAYOUTS.join(', ')} (page #{index})"
    end
  end
end
