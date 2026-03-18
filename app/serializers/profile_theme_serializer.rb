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
      content_max_width: theme.content_max_width,
      card_background_color: theme.card_background_color,
      card_background_opacity: theme.card_background_opacity,
      border_radius: theme.border_radius,
      sections: theme.sections,
      pages: theme.pages,
      single_post_layout: theme.resolved_single_post_layout,
      published_at: theme.published_at,
      has_draft: theme.has_draft?,
      created_at: theme.created_at,
      updated_at: theme.updated_at
    }

    if include_draft
      data[:draft_sections] = theme.draft_sections
      data[:draft_single_post_layout] = theme.draft_single_post_layout
      data[:draft_pages] = theme.draft_pages
    end

    # Include static config for frontend reference
    data[:config] = {
      approved_fonts: ProfileTheme::APPROVED_FONTS,
      section_types: ProfileTheme::SECTION_TYPES,
      max_sections: ProfileTheme::MAX_SECTIONS,
      max_custom_text: ProfileTheme::MAX_CUSTOM_TEXT,
      section_schemas: ProfileSectionFields::SECTION_SCHEMAS,
      social_link_types: ProfileSectionFields::SOCIAL_LINK_TYPES,
      streaming_link_types: ProfileSectionFields::STREAMING_LINK_TYPES,
      page_types: ProfileTheme::PAGE_TYPES,
      page_schemas: {
        links: {
          heading: { type: 'string', max_length: 120, optional: true },
          description: { type: 'string', max_length: 500, optional: true },
          show_social_links: { type: 'boolean', default: true },
          show_streaming_links: { type: 'boolean', default: true },
          layout: { type: 'enum', options: ProfilePageValidator::LINK_PAGE_LAYOUTS, default: 'list' }
        }
      },
      single_post_content_layouts: ProfileTheme::SINGLE_POST_CONTENT_LAYOUTS,
      single_post_layout_schema: {
        show_featured_image: { type: 'boolean', default: true },
        show_author: { type: 'boolean', default: true },
        show_song_embed: { type: 'boolean', default: true },
        show_comments: { type: 'boolean', default: true },
        show_related_posts: { type: 'boolean', default: true },
        show_navigation: { type: 'boolean', default: true },
        content_layout: { type: 'enum', options: ProfileTheme::SINGLE_POST_CONTENT_LAYOUTS, default: 'default' },
        background_color: { type: 'color', optional: true, description: 'Inherits from theme if null' },
        font_color: { type: 'color', optional: true, description: 'Inherits from theme if null' },
        max_width: { type: 'integer', min: 600, max: 1600, optional: true, description: 'Inherits from theme if null' }
      }
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
      },

      # Recent posts for preview (bloggers and bands can have posts)
      posts: build_recent_posts(user),

      # Recent recommendations/reviews for preview
      # For bands: reviews about the band by others. For bloggers: reviews by the user.
      recommendations: build_recent_recommendations(user),
      recommendations_source: user.band? ? 'about_band' : 'by_user',

      # Upcoming events for preview
      events: build_upcoming_events(user),

      # Custom profile links for link page preview
      profile_links: build_profile_links(user),

      # Sample post for single post layout preview in site builder
      sample_post: build_sample_post(user)
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

  # Build array of recent posts for site builder preview
  def self.build_recent_posts(user)
    posts = user.posts.published.order(publish_date: :desc).limit(10)
    posts.map { |p| PostSerializer.summary(p) }
  end

  # Build array of recent recommendations/reviews for site builder preview
  # Band profiles: reviews ABOUT the band by other users
  # Blogger profiles: reviews written BY the user
  def self.build_recent_recommendations(user)
    band = user.primary_band if user.band?

    reviews = if band
                band.reviews
                    .where.not(user_id: user.id)
                    .from_active_users
                    .includes(:user, :track, :band, :mentions)
                    .order(created_at: :desc)
                    .limit(10)
              else
                user.reviews
                    .includes(:track, :band, :mentions)
                    .order(created_at: :desc)
                    .limit(10)
              end

    reviews.map { |r| ReviewSerializer.with_author(r) }
  end

  # Build array of upcoming events for site builder preview
  def self.build_upcoming_events(user)
    events = user.events.active.upcoming.includes(:venue, :band).limit(10)
    events.map { |e| EventSerializer.summary(e) }
  end

  def self.build_profile_links(user)
    user.profile_links.visible.ordered.map do |link|
      {
        id: link.id,
        title: link.title,
        description: link.description,
        url: link.url,
        icon: link.icon,
        position: link.position,
        thumbnail_url: link.thumbnail_url
      }
    end
  end

  def self.build_social_links(user, band = nil)
    ProfileLinkHelper.social_links(user, band)
  end

  def self.build_streaming_links(band)
    ProfileLinkHelper.streaming_links(band)
  end

  def self.public(theme)
    return nil unless theme

    {
      background_color: theme.background_color,
      brand_color: theme.brand_color,
      font_color: theme.font_color,
      header_font: theme.header_font,
      body_font: theme.body_font,
      content_max_width: theme.content_max_width,
      card_background_color: theme.card_background_color,
      card_background_opacity: theme.card_background_opacity,
      border_radius: theme.border_radius,
      single_post_layout: theme.resolved_single_post_layout,
      pages: theme.pages
    }
  end

  # Build a sample post with comments, related posts, and navigation for site builder preview
  def self.build_sample_post(user)
    post = user.posts.published.order(publish_date: :desc).first
    return nil unless post

    data = PostSerializer.full(post)

    # Add sample comments (up to 5)
    comments = post.post_comments.includes(:user, :mentions).order(created_at: :desc).limit(5)
    data[:comments] = comments.map { |c| serialize_preview_comment(c) }

    # Add related posts (up to 3, excluding current post)
    related = user.posts.published.where.not(id: post.id).order(publish_date: :desc).limit(3)
    data[:related_posts] = related.map { |p| PostSerializer.summary(p) }

    # Add navigation (prev/next)
    data[:navigation] = build_post_navigation(user, post)

    data
  end

  def self.serialize_preview_comment(comment)
    result = {
      id: comment.id,
      body: comment.body,
      anonymous: comment.anonymous?,
      likes_count: comment.likes_count,
      created_at: comment.created_at
    }

    if comment.anonymous?
      result[:guest_name] = comment.guest_name
    elsif comment.user
      result[:author] = {
        id: comment.user.id,
        username: comment.user.username,
        display_name: comment.user.display_name,
        profile_image_url: UserSerializer.profile_image_url(comment.user)
      }
    end

    result
  end

  def self.build_post_navigation(user, post)
    posts = user.posts.published.order(publish_date: :desc)

    next_post = posts.where("publish_date > ?", post.publish_date).order(publish_date: :asc).first
    previous_post = posts.where("publish_date < ?", post.publish_date).first

    {
      next_post: next_post ? { title: next_post.title, slug: next_post.slug } : nil,
      previous_post: previous_post ? { title: previous_post.title, slug: previous_post.slug } : nil
    }
  end
end
