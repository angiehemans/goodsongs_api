class UserSerializer
  include Rails.application.routes.url_helpers

  def self.profile_data(user)
    base_data = user.as_json(except: [
      :password_digest, 
      :created_at, 
      :updated_at, 
      :spotify_access_token, 
      :spotify_refresh_token
    ])
    
    base_data.merge(
      reviews_count: user.reviews.count,
      bands_count: user.bands.count,
      spotify_connected: user.spotify_access_token.present?,
      profile_image_url: user.profile_image.attached? ? 
        Rails.application.routes.url_helpers.url_for(user.profile_image) : nil
    )
  end

  def self.public_profile(user)
    {
      id: user.id,
      username: user.username,
      email: user.email,
      about_me: user.about_me,
      profile_image_url: user.profile_image.attached? ? 
        Rails.application.routes.url_helpers.url_for(user.profile_image) : nil,
      reviews_count: user.reviews.count,
      bands_count: user.bands.count
    }
  end
end