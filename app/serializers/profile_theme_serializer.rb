class ProfileThemeSerializer
  extend ImageUrlHelper

  def self.full(theme, include_draft: false, user: nil)
    return nil unless theme

    # Use provided user or fetch from theme
    user ||= theme.user

    data = {
      id: theme.id,
      user_id: theme.user_id,
      background_color: theme.background_color,
      brand_color: theme.brand_color,
      font_color: theme.font_color,
      header_font: theme.header_font,
      body_font: theme.body_font,
      sections: theme.sections,
      published_at: theme.published_at,
      has_draft: theme.has_draft?,
      created_at: theme.created_at,
      updated_at: theme.updated_at
    }

    if include_draft
      data[:draft_sections] = theme.draft_sections
    end

    # Include static config for frontend reference
    data[:config] = {
      approved_fonts: ProfileTheme::APPROVED_FONTS,
      section_types: ProfileTheme::SECTION_TYPES,
      max_sections: ProfileTheme::MAX_SECTIONS,
      max_custom_text: ProfileTheme::MAX_CUSTOM_TEXT,
      section_schemas: ProfileSectionFields::SECTION_SCHEMAS,
      social_link_types: ProfileSectionFields::SOCIAL_LINK_TYPES,
      streaming_link_types: ProfileSectionFields::STREAMING_LINK_TYPES
    }

    # Include source data for site builder preview
    # This contains the actual user/band data that sections will display
    data[:source_data] = build_source_data(user) if user

    data
  end

  # Build the source data object containing all user/band data for previews
  def self.build_source_data(user)
    band = user.primary_band if user.band?

    data = {
      # Core profile data (maps to schema sources)
      display_name: user.display_name,
      location: user.location || band&.location,
      about_text: band&.about || user.about_me,
      profile_image_url: profile_image_url(user),

      # User's configured social links
      social_links: build_social_links(user, band),

      # User info
      user: {
        id: user.id,
        username: user.username,
        role: user.role
      }
    }

    # Include band data if applicable
    if band
      data[:band] = {
        id: band.id,
        slug: band.slug,
        name: band.name,
        location: band.location,
        about: band.about,
        profile_picture_url: BandSerializer.band_image_url(band)
      }

      # Band's configured streaming links
      data[:streaming_links] = build_streaming_links(band)
    end

    data
  end

  # Build hash of user's configured social links
  def self.build_social_links(user, band = nil)
    links = {}

    ProfileSectionFields::SOCIAL_LINK_TYPES.each do |platform|
      field = "#{platform}_url"

      # Check user first
      if user.respond_to?(field) && user.send(field).present?
        links[platform] = user.send(field)
      end

      # For band users, band links take precedence
      if band && band.respond_to?(field) && band.send(field).present?
        links[platform] = band.send(field) if user.band?
        links[platform] ||= band.send(field)
      end
    end

    links
  end

  # Build hash of band's configured streaming links
  def self.build_streaming_links(band)
    return {} unless band

    links = {}
    links['spotify'] = band.spotify_link if band.spotify_link.present?
    links['appleMusic'] = band.apple_music_link if band.apple_music_link.present?
    links['bandcamp'] = band.bandcamp_link if band.bandcamp_link.present?
    links['soundcloud'] = band.soundcloud_link if band.soundcloud_link.present?
    links['youtubeMusic'] = band.youtube_music_link if band.youtube_music_link.present?
    links
  end

  def self.public(theme)
    return nil unless theme

    {
      background_color: theme.background_color,
      brand_color: theme.brand_color,
      font_color: theme.font_color,
      header_font: theme.header_font,
      body_font: theme.body_font
    }
  end
end
