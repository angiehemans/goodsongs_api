# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  before_action :require_admin

  # GET /admin/users
  def users
    users = User.all.order(created_at: :desc)
    json_response(users.map { |user| admin_user_data(user) })
  end

  # GET /admin/users/:id
  def user_detail
    user = User.find(params[:id])
    reviews = user.reviews.includes(:band).order(created_at: :desc)
    bands = user.bands.order(:name)

    json_response({
      user: admin_user_data_full(user),
      reviews: reviews.map { |review| ReviewSerializer.full(review) },
      bands: bands.map { |band| admin_band_data(band) }
    })
  end

  # PATCH /admin/users/:id/toggle-disabled
  def toggle_disabled
    user = User.find(params[:id])

    # Prevent admin from disabling themselves
    if user.id == current_user.id
      return json_response({ error: 'You cannot disable your own account' }, :unprocessable_entity)
    end

    user.update!(disabled: !user.disabled)

    json_response({
      message: user.disabled? ? 'User has been disabled' : 'User has been enabled',
      user: admin_user_data(user)
    })
  end

  # PATCH /admin/users/:id
  def update_user
    user = User.find(params[:id])

    # Prevent admin from modifying their own admin status
    if user.id == current_user.id && params[:admin].present? && params[:admin] != user.admin?
      return json_response({ error: 'You cannot modify your own admin status' }, :unprocessable_entity)
    end

    if user.update(admin_user_params)
      json_response({
        message: 'User has been updated',
        user: admin_user_data_full(user)
      })
    else
      json_response({ errors: user.errors.full_messages }, :unprocessable_entity)
    end
  end

  # DELETE /admin/users/:id
  def destroy_user
    user = User.find(params[:id])

    # Prevent admin from deleting themselves
    if user.id == current_user.id
      return json_response({ error: 'You cannot delete your own account' }, :unprocessable_entity)
    end

    user.destroy!
    json_response({ message: 'User has been deleted' })
  end

  # GET /admin/bands
  def bands
    bands = Band.all.includes(:user, :reviews).order(:name)
    json_response(bands.map { |band| admin_band_data(band) })
  end

  # GET /admin/bands/:id
  def band_detail
    band = Band.find(params[:id])
    reviews = band.reviews.includes(:user).order(created_at: :desc)
    events = band.events.includes(:venue).order(event_date: :desc)

    json_response({
      band: admin_band_data_full(band),
      reviews: reviews.map { |review| ReviewSerializer.full(review) },
      events: events.map { |event| EventSerializer.full(event) }
    })
  end

  # PATCH /admin/bands/:id
  def update_band
    band = Band.find(params[:id])

    if band.update(admin_band_params)
      json_response({
        message: 'Band has been updated',
        band: admin_band_data_full(band)
      })
    else
      json_response({ errors: band.errors.full_messages }, :unprocessable_entity)
    end
  end

  # PATCH /admin/bands/:id/toggle-disabled
  def toggle_band_disabled
    band = Band.find(params[:id])
    band.update!(disabled: !band.disabled)

    json_response({
      message: band.disabled? ? 'Band has been disabled' : 'Band has been enabled',
      band: admin_band_data(band)
    })
  end

  # DELETE /admin/bands/:id
  def destroy_band
    band = Band.find(params[:id])

    # Nullify primary_band reference for any users who have this as their primary band
    User.where(primary_band_id: band.id).update_all(primary_band_id: nil)

    band.destroy!
    json_response({ message: 'Band has been deleted' })
  end

  # GET /admin/reviews
  def reviews
    reviews = Review.all.includes(:user, :band).order(created_at: :desc)
    json_response(reviews.map { |review| ReviewSerializer.full(review) })
  end

  # DELETE /admin/reviews/:id
  def destroy_review
    review = Review.find(params[:id])
    review.destroy!
    json_response({ message: 'Review has been deleted' })
  end

  private

  def admin_user_params
    params.permit(
      :email,
      :username,
      :about_me,
      :city,
      :region,
      :admin,
      :disabled,
      :account_type,
      :lastfm_username,
      :onboarding_completed,
      :profile_image
    )
  end

  def admin_user_data(user)
    UserSerializer.public_profile(user).merge(
      admin: user.admin?,
      disabled: user.disabled?
    )
  end

  # Full user data for admin editing - includes all editable fields
  def admin_user_data_full(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      about_me: user.about_me,
      city: user.city,
      region: user.region,
      location: user.location,
      latitude: user.latitude,
      longitude: user.longitude,
      account_type: user.account_type,
      onboarding_completed: user.onboarding_completed,
      admin: user.admin?,
      disabled: user.disabled?,
      lastfm_username: user.lastfm_username,
      lastfm_connected: user.lastfm_connected?,
      profile_image_url: UserSerializer.profile_image_url(user),
      display_name: user.display_name,
      reviews_count: user.reviews.count,
      bands_count: user.bands.count,
      followers_count: user.followers.count,
      following_count: user.following.count,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def admin_band_params
    params.permit(
      :name,
      :slug,
      :about,
      :city,
      :region,
      :disabled,
      :user_id,
      :spotify_link,
      :bandcamp_link,
      :bandcamp_embed,
      :apple_music_link,
      :youtube_music_link,
      :musicbrainz_id,
      :lastfm_artist_name,
      :artist_image_url,
      :profile_picture
    )
  end

  def admin_band_data(band)
    BandSerializer.full(band).merge(
      disabled: band.disabled?
    )
  end

  # Full band data for admin editing - includes all editable fields
  def admin_band_data_full(band)
    {
      id: band.id,
      name: band.name,
      slug: band.slug,
      about: band.about,
      city: band.city,
      region: band.region,
      location: band.location,
      latitude: band.latitude,
      longitude: band.longitude,
      disabled: band.disabled?,
      user_id: band.user_id,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username, email: band.user.email } : nil,
      spotify_link: band.spotify_link,
      bandcamp_link: band.bandcamp_link,
      bandcamp_embed: band.bandcamp_embed,
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      musicbrainz_id: band.musicbrainz_id,
      lastfm_artist_name: band.lastfm_artist_name,
      lastfm_url: band.lastfm_url,
      artist_image_url: band.artist_image_url,
      profile_picture_url: BandSerializer.band_image_url(band),
      reviews_count: band.reviews.count,
      events_count: band.events.count,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end
end
