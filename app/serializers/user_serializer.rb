class UserSerializer
  include ImageSerializable
  extend ImageUrlHelper

  def self.profile_data(user)
    base_data = user.as_json(except: [
      :password_digest,
      :created_at,
      :updated_at,
      :spotify_access_token,
      :spotify_refresh_token,
      :spotify_expires_at,
      :primary_band_id
    ])

    result = base_data.merge(
      reviews_count: user.reviews.count,
      bands_count: user.bands.count,
      lastfm_connected: user.lastfm_connected?,
      lastfm_username: user.lastfm_username,
      profile_image_url: profile_image_url(user),
      account_type: user.account_type,
      onboarding_completed: user.onboarding_completed,
      display_name: user.display_name,
      admin: user.admin?,
      city: user.city,
      region: user.region,
      location: user.location,
      latitude: user.latitude,
      longitude: user.longitude,
      followers_count: user.followers.count,
      following_count: user.following.count
    )

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
      email: user.email,
      about_me: user.about_me,
      profile_image_url: profile_image_url(user),
      reviews_count: user.reviews.count,
      bands_count: user.bands.count,
      account_type: user.account_type,
      onboarding_completed: user.onboarding_completed,
      display_name: user.display_name,
      location: user.location,
      followers_count: user.followers.count,
      following_count: user.following.count
    }

    # Include primary band for BAND accounts
    if user.band? && user.primary_band
      result[:primary_band] = BandSerializer.summary(user.primary_band)
    end

    result
  end
end