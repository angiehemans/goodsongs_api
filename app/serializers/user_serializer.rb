class UserSerializer
  include ImageSerializable
  extend ImageUrlHelper

  def self.profile_data(user)
    result = {
      id: user.id,
      email: user.email,
      username: user.username,
      about_me: user.about_me,
      profile_image_url: profile_image_url(user),
      display_name: user.display_name,
      role: user.role,
      admin: user.admin?,
      onboarding_completed: user.onboarding_completed,
      email_confirmed: user.email_confirmed?,
      can_resend_confirmation: user.can_resend_confirmation?,
      # Location
      city: user.city,
      region: user.region,
      location: user.location,
      latitude: user.latitude,
      longitude: user.longitude,
      # Counts (use counter caches)
      reviews_count: user.reviews_count,
      bands_count: user.bands.count,
      followers_count: user.followers_count,
      following_count: user.following_count,
      # Last.fm
      lastfm_connected: user.lastfm_connected?,
      lastfm_username: user.lastfm_username,
      # Plan & abilities
      plan: user.plan ? { key: user.plan.key, name: user.plan.name } : nil,
      abilities: user.abilities,
      # Preferences
      preferred_streaming_platform: user.preferred_streaming_platform,
      allow_anonymous_comments: user.allow_anonymous_comments,
      dark_mode: user.dark_mode,
      # Social links
      social_links: social_links(user)
    }

    # Include primary band for BAND accounts
    if user.band? && user.primary_band
      result[:primary_band] = BandSerializer.summary(user.primary_band)
    end

    result
  end

  def self.public_profile(user)
    result = {
      id: user.id,
      username: user.username,
      about_me: user.about_me,
      profile_image_url: profile_image_url(user),
      reviews_count: user.reviews_count,       # Use counter cache
      bands_count: user.bands.count,
      role: user.role,
      onboarding_completed: user.onboarding_completed,
      display_name: user.display_name,
      location: user.location,
      followers_count: user.followers_count,   # Use counter cache
      following_count: user.following_count,   # Use counter cache
      allow_anonymous_comments: user.allow_anonymous_comments,
      # Social links
      social_links: social_links(user)
    }

    # Include primary band for BAND accounts
    if user.band? && user.primary_band
      result[:primary_band] = BandSerializer.summary(user.primary_band)
    end

    result
  end

  # Returns hash of configured social links
  def self.social_links(user)
    links = {}
    %w[instagram threads bluesky twitter tumblr tiktok facebook youtube].each do |platform|
      field = "#{platform}_url"
      value = user.send(field) if user.respond_to?(field)
      links[platform] = value if value.present?
    end
    links
  end
end