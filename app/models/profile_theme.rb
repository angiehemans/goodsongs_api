class ProfileTheme < ApplicationRecord
  belongs_to :user

  SECTION_TYPES = %w[
    hero
    music
    events
    posts
    about
    recommendations
    custom_text
    mailing_list
    merch
  ].freeze

  PREDEFINED_SECTION_TYPES = %w[
    hero
    music
    events
    posts
    about
    recommendations
    mailing_list
    merch
  ].freeze

  APPROVED_FONTS = [
    'Inter',
    'Space Grotesk',
    'DM Sans',
    'Plus Jakarta Sans',
    'Outfit',
    'Sora',
    'Manrope',
    'Rubik',
    'Work Sans',
    'Nunito Sans',
    'Lora',
    'Merriweather',
    'Playfair Display',
    'Source Serif 4',
    'Libre Baskerville',
    'IBM Plex Mono',
    'JetBrains Mono',
    'Creepster',
    'Jacquard 12',
    'Astloch',
    'Pirata One',
    'Special Elite',
    'Courier Prime',
    'Cutive Mono',
  ].freeze

  MAX_SECTIONS = 12
  MAX_CUSTOM_TEXT = 3

  SINGLE_POST_CONTENT_LAYOUTS = %w[default wide narrow].freeze

  DEFAULT_SINGLE_POST_LAYOUT = {
    'show_featured_image' => true,
    'show_author' => true,
    'show_song_embed' => true,
    'show_comments' => true,
    'show_related_posts' => true,
    'show_navigation' => true,
    'content_layout' => 'default',
    'background_color' => nil,
    'font_color' => nil,
    'max_width' => nil
  }.freeze

  # Color validation regex for hex colors
  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/

  validates :user, presence: true, uniqueness: true
  validates :background_color, format: { with: HEX_COLOR_REGEX, message: "must be a valid hex color" }
  validates :brand_color, format: { with: HEX_COLOR_REGEX, message: "must be a valid hex color" }
  validates :font_color, format: { with: HEX_COLOR_REGEX, message: "must be a valid hex color" }
  validates :header_font, inclusion: { in: APPROVED_FONTS, message: "is not an approved font" }
  validates :body_font, inclusion: { in: APPROVED_FONTS, message: "is not an approved font" }
  validates :card_background_color, format: { with: HEX_COLOR_REGEX, message: "must be a valid hex color" }, allow_nil: true
  validates :card_background_opacity, numericality: { only_integer: true, in: 0..100, message: "must be between 0 and 100" }
  validate :validate_sections_structure

  def self.default_sections_for_role(role)
    case role.to_s
    when 'band'
      [
        { type: 'hero', visible: true, order: 0 },
        { type: 'music', visible: true, order: 1 },
        { type: 'events', visible: true, order: 2 },
        { type: 'about', visible: true, order: 3 },
        { type: 'recommendations', visible: true, order: 4 },
        { type: 'mailing_list', visible: false, order: 5 },
        { type: 'merch', visible: false, order: 6 }
      ]
    when 'blogger'
      [
        { type: 'hero', visible: true, order: 0 },
        { type: 'posts', visible: true, order: 1 },
        { type: 'about', visible: true, order: 2 },
        { type: 'recommendations', visible: true, order: 3 },
        { type: 'mailing_list', visible: false, order: 4 }
      ]
    else
      []
    end
  end

  def publish!
    return false unless has_draft?

    attrs = { published_at: Time.current }

    if draft_sections.present?
      attrs[:sections] = draft_sections
      attrs[:draft_sections] = nil
    end

    if draft_single_post_layout.present?
      attrs[:single_post_layout] = draft_single_post_layout
      attrs[:draft_single_post_layout] = nil
    end

    update!(attrs)
  end

  def discard_draft!
    update!(draft_sections: nil, draft_single_post_layout: nil)
  end

  def reset_to_defaults!
    default_sections = self.class.default_sections_for_role(user.role)
    update!(
      background_color: '#121212',
      brand_color: '#6366f1',
      font_color: '#f5f5f5',
      header_font: 'Inter',
      body_font: 'Inter',
      card_background_color: nil,
      card_background_opacity: 10,
      sections: default_sections,
      draft_sections: nil,
      single_post_layout: {},
      draft_single_post_layout: nil,
      published_at: nil
    )
  end

  def has_draft?
    draft_sections.present? || draft_single_post_layout.present?
  end

  def resolved_single_post_layout
    DEFAULT_SINGLE_POST_LAYOUT.merge(single_post_layout || {})
  end

  def active_sections
    sections.select { |s| s['visible'] == true }
  end

  private

  def validate_sections_structure
    return if sections.blank?

    unless sections.is_a?(Array)
      errors.add(:sections, "must be an array")
      return
    end

    if sections.length > MAX_SECTIONS
      errors.add(:sections, "cannot have more than #{MAX_SECTIONS} sections")
    end

    custom_text_count = sections.count { |s| s['type'] == 'custom_text' }
    if custom_text_count > MAX_CUSTOM_TEXT
      errors.add(:sections, "cannot have more than #{MAX_CUSTOM_TEXT} custom_text sections")
    end

    # Check predefined sections appear at most once
    PREDEFINED_SECTION_TYPES.each do |section_type|
      count = sections.count { |s| s['type'] == section_type }
      if count > 1
        errors.add(:sections, "#{section_type} section can only appear once")
      end
    end

    # Check all section types are valid
    sections.each_with_index do |section, index|
      unless section.is_a?(Hash)
        errors.add(:sections, "section at index #{index} must be an object")
        next
      end

      type = section['type']
      unless SECTION_TYPES.include?(type)
        errors.add(:sections, "invalid section type '#{type}' at index #{index}")
      end
    end

    # At least one visible section
    visible_count = sections.count { |s| s['visible'] == true }
    if visible_count == 0 && sections.any?
      errors.add(:sections, "must have at least one visible section")
    end
  end
end
