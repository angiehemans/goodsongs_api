# frozen_string_literal: true

module ProfileSectionFields
  extend ActiveSupport::Concern

  SOCIAL_LINK_TYPES = %w[instagram threads bluesky twitter tumblr tiktok facebook youtube].freeze
  STREAMING_LINK_TYPES = %w[spotify appleMusic bandcamp soundcloud youtubeMusic].freeze

  SECTION_SCHEMAS = {
    hero: {
      content: {
        headline: { source: :display_name, max_length: 120 },
        subtitle: { source: :location, max_length: 200 },
        cta_text: { max_length: 40 },
        cta_url: { format: :url }
      },
      settings: {
        background_color: { type: :color },
        background_image_url: { type: :url },
        font_color: { type: :color },
        show_profile_image: { type: :boolean, default: true },
        show_subtitle: { type: :boolean, default: true },
        show_cta: { type: :boolean, default: true },
        visible_social_links: { type: :array, default: :configured },
        visible_streaming_links: { type: :array, default: :configured }
      }
    },
    music: {
      content: {
        heading: { default: 'Music', max_length: 60 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        display_limit: { type: :integer, default: 6, min: 1, max: 24 },
        layout: { type: :enum, values: %w[grid list], default: 'grid' },
        show_bandcamp_embed: { type: :boolean, default: true }
      }
    },
    events: {
      content: {
        heading: { default: 'Events', max_length: 60 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        display_limit: { type: :integer, default: 6, min: 1, max: 12 },
        show_past_events: { type: :boolean, default: false }
      }
    },
    posts: {
      content: {
        heading: { default: 'Posts', max_length: 60 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        display_limit: { type: :integer, default: 6, min: 1, max: 12 },
        layout: { type: :enum, values: %w[grid list], default: 'grid' }
      }
    },
    about: {
      content: {
        heading: { default: 'About', max_length: 60 },
        bio: { source: :about_text, max_length: 5000 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        show_location: { type: :boolean, default: true },
        show_social_links: { type: :boolean, default: true },
        visible_social_links: { type: :array, default: :configured }
      }
    },
    recommendations: {
      content: {
        heading: { default: 'Recommendations', max_length: 60 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        display_limit: { type: :integer, default: 12, min: 1, max: 24 },
        layout: { type: :enum, values: %w[grid list], default: 'grid' }
      }
    },
    custom_text: {
      content: {
        heading: { max_length: 120 },
        body: { max_length: 10000 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color }
      }
    },
    mailing_list: {
      content: {
        heading: { default: 'Stay in the loop', max_length: 120 },
        description: { max_length: 500 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        provider: { type: :enum, values: %w[native mailchimp convertkit], default: 'native' },
        external_form_url: { type: :url }
      }
    },
    merch: {
      content: {
        heading: { default: 'Merch', max_length: 120 }
      },
      settings: {
        background_color: { type: :color },
        font_color: { type: :color },
        provider: { type: :enum, values: %w[bandcamp bigcartel shopify custom], default: 'bandcamp' },
        external_url: { type: :url },
        display_limit: { type: :integer, default: 6, min: 1, max: 12 }
      }
    }
  }.freeze

  # Helper to get schema for a section type
  def self.schema_for(type)
    SECTION_SCHEMAS[type.to_sym] || {}
  end

  # Get all available settings fields for a section type
  def self.settings_fields_for(type)
    SECTION_SCHEMAS.dig(type.to_sym, :settings)&.keys || []
  end

  # Get all available content fields for a section type
  def self.content_fields_for(type)
    SECTION_SCHEMAS.dig(type.to_sym, :content)&.keys || []
  end
end
