# frozen_string_literal: true

class ProfileThemeValidator
  include ProfileSectionFields

  MAX_SECTIONS = ProfileTheme::MAX_SECTIONS
  MAX_CUSTOM_TEXT = ProfileTheme::MAX_CUSTOM_TEXT
  SECTION_TYPES = ProfileTheme::SECTION_TYPES
  PREDEFINED_SECTION_TYPES = ProfileTheme::PREDEFINED_SECTION_TYPES

  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/
  URL_REGEX = /\Ahttps?:\/\/.+/i

  attr_reader :errors

  def initialize(user, sections)
    @user = user
    @sections = sections
    @errors = []
  end

  def valid?
    @errors = []

    validate_array_format
    return false if @errors.any?

    validate_section_count
    validate_section_types
    validate_custom_text_limit
    validate_predefined_uniqueness
    validate_visible_section
    validate_plan_gated_sections
    validate_section_content_and_settings

    @errors.empty?
  end

  def error_messages
    @errors.join(', ')
  end

  private

  def validate_array_format
    unless @sections.is_a?(Array) || @sections.respond_to?(:each_with_index)
      @errors << "Sections must be an array"
    end
  end

  def validate_section_count
    if @sections.length > MAX_SECTIONS
      @errors << "Cannot have more than #{MAX_SECTIONS} sections"
    end
  end

  def validate_section_types
    @sections.each_with_index do |section, index|
      unless section.is_a?(Hash) || section.is_a?(ActionController::Parameters)
        @errors << "Section at index #{index} must be an object"
        next
      end

      type = section['type'] || section[:type]
      unless SECTION_TYPES.include?(type)
        @errors << "Invalid section type '#{type}' at index #{index}"
      end

      # Validate required fields
      if section['order'].nil? && section[:order].nil?
        @errors << "Section at index #{index} missing 'order' field"
      end

      if section['visible'].nil? && section[:visible].nil?
        @errors << "Section at index #{index} missing 'visible' field"
      end
    end
  end

  def validate_custom_text_limit
    custom_text_count = @sections.count { |s| (s['type'] || s[:type]) == 'custom_text' }
    if custom_text_count > MAX_CUSTOM_TEXT
      @errors << "Cannot have more than #{MAX_CUSTOM_TEXT} custom_text sections"
    end
  end

  def validate_predefined_uniqueness
    PREDEFINED_SECTION_TYPES.each do |section_type|
      count = @sections.count { |s| (s['type'] || s[:type]) == section_type }
      if count > 1
        @errors << "#{section_type} section can only appear once"
      end
    end
  end

  def validate_visible_section
    visible_count = @sections.count do |s|
      visible = s['visible'].nil? ? s[:visible] : s['visible']
      visible == true
    end

    if visible_count == 0 && @sections.any?
      @errors << "Must have at least one visible section"
    end
  end

  def validate_plan_gated_sections
    @sections.each_with_index do |section, _index|
      type = section['type'] || section[:type]
      visible = section['visible'].nil? ? section[:visible] : section['visible']

      # Only check visible sections for plan gating
      next unless visible

      case type
      when 'mailing_list'
        unless @user.can?(:profile_mailing_list_section)
          @errors << "Mailing list section requires a plan upgrade"
        end
      when 'merch'
        unless @user.can?(:profile_merch_section)
          @errors << "Merch section requires Band Pro plan"
        end
      end
    end
  end

  def validate_section_content_and_settings
    @sections.each_with_index do |section, index|
      type = (section['type'] || section[:type]).to_s.to_sym
      content = section['content'] || section[:content] || {}
      settings = section['settings'] || section[:settings] || {}

      schema = SECTION_SCHEMAS[type]
      next unless schema

      # Validate content fields
      validate_content_fields(content, schema[:content], type, index) if schema[:content]

      # Validate settings fields
      validate_settings_fields(settings, schema[:settings], type, index) if schema[:settings]
    end
  end

  def validate_content_fields(content, schema, type, index)
    schema.each do |field, config|
      value = content[field.to_s] || content[field]
      next if value.nil?

      # Validate max_length
      if config[:max_length] && value.is_a?(String) && value.length > config[:max_length]
        @errors << "#{type} #{field} exceeds #{config[:max_length]} characters (section #{index})"
      end

      # Validate URL format
      if config[:format] == :url && value.present? && !value.match?(URL_REGEX)
        @errors << "#{type} #{field} must be a valid URL (section #{index})"
      end
    end
  end

  def validate_settings_fields(settings, schema, type, index)
    schema.each do |field, config|
      value = settings[field.to_s] || settings[field]
      next if value.nil?

      case config[:type]
      when :boolean
        unless [true, false].include?(value)
          @errors << "#{type} #{field} must be true or false (section #{index})"
        end
      when :integer
        unless value.is_a?(Integer)
          @errors << "#{type} #{field} must be an integer (section #{index})"
          next
        end
        if config[:min] && value < config[:min]
          @errors << "#{type} #{field} must be at least #{config[:min]} (section #{index})"
        end
        if config[:max] && value > config[:max]
          @errors << "#{type} #{field} must be at most #{config[:max]} (section #{index})"
        end
      when :enum
        # Allow custom enum values for flexibility in site builder
        # Schema values are suggestions, not strict requirements
        next
      when :color
        if value.present? && !value.match?(HEX_COLOR_REGEX)
          @errors << "#{type} #{field} must be a valid hex color (section #{index})"
        end
      when :url
        if value.present? && !value.match?(URL_REGEX)
          @errors << "#{type} #{field} must be a valid URL (section #{index})"
        end
      when :array
        unless value.is_a?(Array)
          @errors << "#{type} #{field} must be an array (section #{index})"
        end
      end
    end
  end
end
