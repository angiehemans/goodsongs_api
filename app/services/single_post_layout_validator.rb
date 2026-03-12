class SinglePostLayoutValidator
  BOOLEAN_FIELDS = %w[
    show_featured_image
    show_author
    show_song_embed
    show_comments
    show_related_posts
    show_navigation
  ].freeze

  OPTIONAL_COLOR_FIELDS = %w[background_color font_color].freeze

  ALLOWED_KEYS = (BOOLEAN_FIELDS + OPTIONAL_COLOR_FIELDS + %w[content_layout max_width]).freeze

  attr_reader :errors

  def initialize(layout)
    @layout = layout || {}
    @errors = []
  end

  def valid?
    @errors = []

    unless @layout.is_a?(Hash)
      @errors << "single_post_layout must be a hash"
      return false
    end

    validate_no_unknown_keys
    validate_boolean_fields
    validate_content_layout
    validate_color_fields
    validate_max_width

    @errors.empty?
  end

  def error_messages
    @errors.join(', ')
  end

  private

  def validate_no_unknown_keys
    unknown = @layout.keys.map(&:to_s) - ALLOWED_KEYS
    unknown.each { |k| @errors << "unknown key '#{k}'" }
  end

  def validate_boolean_fields
    BOOLEAN_FIELDS.each do |field|
      next unless @layout.key?(field)
      value = @layout[field]
      unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
        @errors << "#{field} must be a boolean"
      end
    end
  end

  def validate_content_layout
    return unless @layout.key?('content_layout')
    value = @layout['content_layout']
    unless ProfileTheme::SINGLE_POST_CONTENT_LAYOUTS.include?(value)
      @errors << "content_layout must be one of: #{ProfileTheme::SINGLE_POST_CONTENT_LAYOUTS.join(', ')}"
    end
  end

  def validate_color_fields
    OPTIONAL_COLOR_FIELDS.each do |field|
      next unless @layout.key?(field)
      value = @layout[field]
      next if value.nil?
      unless value.is_a?(String) && value.match?(ProfileTheme::HEX_COLOR_REGEX)
        @errors << "#{field} must be a valid hex color (e.g. #FF0000) or null"
      end
    end
  end

  def validate_max_width
    return unless @layout.key?('max_width')
    value = @layout['max_width']
    return if value.nil?
    unless value.is_a?(Integer) && value >= 600 && value <= 1600
      @errors << "max_width must be an integer between 600 and 1600, or null"
    end
  end
end
