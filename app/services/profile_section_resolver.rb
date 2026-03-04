# frozen_string_literal: true

class ProfileSectionResolver
  include ProfileSectionFields

  def initialize(user)
    @user = user
    @band = user.primary_band if user.band?
  end

  def resolve_section(section)
    type = (section['type'] || section[:type]).to_s.to_sym
    content = section['content'] || section[:content] || {}
    settings = section['settings'] || section[:settings] || {}

    {
      type: type,
      order: section['order'] || section[:order],
      content: resolve_content(type, content),
      settings: resolve_settings(type, settings),
      data: hydrate_data(type, settings)
    }
  end

  private

  def resolve_content(type, content)
    schema = SECTION_SCHEMAS.dig(type, :content) || {}
    resolved = {}

    # First, pass through ALL content fields from the stored section
    content.each do |key, value|
      resolved[key.to_sym] = value
    end

    # Then, apply schema defaults and source resolution for missing fields
    schema.each do |field, config|
      next if resolved.key?(field) || resolved.key?(field.to_s)

      if config[:source]
        resolved[field] = resolve_source(config[:source])
      elsif config[:default]
        resolved[field] = config[:default]
      end
    end

    resolved
  end

  def resolve_settings(type, settings)
    schema = SECTION_SCHEMAS.dig(type, :settings) || {}
    resolved = {}

    # First, pass through ALL settings from the stored section
    settings.each do |key, value|
      resolved[key.to_sym] = value
    end

    # Then, apply schema defaults for missing fields
    schema.each do |field, config|
      next if resolved.key?(field) || resolved.key?(field.to_s)

      resolved[field] = config[:default] if config[:default]
    end

    resolved
  end

  def resolve_source(source)
    case source
    when :display_name
      @user.display_name
    when :location
      @user.location || @band&.location
    when :about_text
      @band&.about || @user.about_me
    else
      nil
    end
  end

  def hydrate_data(type, settings)
    case type
    when :hero
      hydrate_hero(settings)
    when :music
      hydrate_music(settings)
    when :events
      hydrate_events(settings)
    when :posts
      hydrate_posts(settings)
    when :about
      hydrate_about(settings)
    when :recommendations
      hydrate_recommendations(settings)
    else
      {}
    end
  end

  def hydrate_hero(settings)
    data = {
      display_name: @user.display_name,
      profile_image_url: profile_image_url,
      location: @user.location || @band&.location
    }

    # Resolve streaming links (only configured ones, filtered by visibility)
    data[:streaming_links] = filter_links(
      configured_streaming_links,
      settings['visible_streaming_links'] || settings[:visible_streaming_links]
    )

    # Resolve social links
    data[:social_links] = filter_links(
      configured_social_links,
      settings['visible_social_links'] || settings[:visible_social_links]
    )

    data[:band] = BandSerializer.summary(@band) if @band

    data
  end

  def hydrate_music(settings)
    return {} unless @band

    limit = settings['display_limit'] || settings[:display_limit] || 6
    tracks = @band.tracks.order(created_at: :desc).limit(limit)

    {
      band: BandSerializer.summary(@band),
      tracks: tracks.map { |t| TrackSerializer.summary(t) },
      bandcamp_embed: @band.bandcamp_embed,
      streaming_links: configured_streaming_links
    }
  end

  def hydrate_events(settings)
    limit = settings['display_limit'] || settings[:display_limit] || 6
    show_past = settings['show_past_events'] || settings[:show_past_events] || false

    # Include both band events and user's own events
    scope = @user.events.active.includes(:venue, :band)
    events = if show_past
               scope.order(event_date: :desc).limit(limit)
             else
               scope.upcoming.limit(limit)
             end

    {
      events: events.map { |e| EventSerializer.summary(e) }
    }
  end

  def hydrate_posts(settings)
    limit = settings['display_limit'] || settings[:display_limit] || 6
    posts = @user.posts.published.order(publish_date: :desc).limit(limit)

    {
      posts: posts.map { |p| PostSerializer.summary(p) }
    }
  end

  def hydrate_about(settings)
    data = {
      about_me: @user.about_me,
      bio: @band&.about || @user.about_me,
      location: @user.location || @band&.location
    }

    # Include social links if enabled
    show_social = settings['show_social_links'] || settings[:show_social_links]
    if show_social != false
      data[:social_links] = filter_links(
        configured_social_links,
        settings['visible_social_links'] || settings[:visible_social_links]
      )
    end

    data[:band] = BandSerializer.summary(@band) if @band

    data
  end

  def hydrate_recommendations(settings)
    limit = settings['display_limit'] || settings[:display_limit] || 12
    reviews = @user.reviews.includes(:track, :band, :mentions).order(created_at: :desc).limit(limit)

    {
      reviews: reviews.map { |r| ReviewSerializer.with_author(r) }
    }
  end

  def configured_streaming_links
    return {} unless @band

    links = {}
    links['spotify'] = @band.spotify_link if @band.spotify_link.present?
    links['appleMusic'] = @band.apple_music_link if @band.apple_music_link.present?
    links['bandcamp'] = @band.bandcamp_link if @band.bandcamp_link.present?
    links['soundcloud'] = @band.soundcloud_link if @band.soundcloud_link.present?
    links['youtubeMusic'] = @band.youtube_music_link if @band.youtube_music_link.present?
    links
  end

  def configured_social_links
    links = {}

    # Social link field names matching SOCIAL_LINK_TYPES
    social_fields = %w[instagram threads bluesky twitter tumblr tiktok facebook youtube]

    # User social links
    social_fields.each do |platform|
      field = "#{platform}_url"
      if @user.respond_to?(field) && @user.send(field).present?
        links[platform] = @user.send(field)
      end
    end

    # Band social links (if band exists) - band links take precedence for band users
    if @band
      social_fields.each do |platform|
        field = "#{platform}_url"
        if @band.respond_to?(field) && @band.send(field).present?
          # For band users, band links take precedence
          links[platform] = @band.send(field) if @user.band?
          # For non-band users, only use band link if user doesn't have one
          links[platform] ||= @band.send(field)
        end
      end
    end

    links
  end

  def filter_links(all_links, visible_setting)
    # :configured or nil means show all configured links
    return all_links if visible_setting == :configured || visible_setting == 'configured' || visible_setting.nil?

    # Empty array means show none
    return {} if visible_setting.is_a?(Array) && visible_setting.empty?

    # Array of link types to show (whitelist)
    if visible_setting.is_a?(Array)
      all_links.slice(*visible_setting.map(&:to_s))
    else
      all_links
    end
  end

  def profile_image_url
    return nil unless @user.profile_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      @user.profile_image,
      **active_storage_url_options
    )
  end

  def active_storage_url_options
    if ENV['API_URL'].present?
      uri = URI.parse(ENV['API_URL'])
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
    else
      Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
    end
  end
end
