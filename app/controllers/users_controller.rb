# app/controllers/users_controller.rb
class UsersController < ApplicationController
  include ExceptionHandler
  
  skip_before_action :authenticate_request, only: [:create, :profile_by_username]

  def create
    user = User.create!(user_params)
    auth_token = AuthenticateUser.new(user.email, user.password).call
    response = { message: Message.account_created, auth_token: auth_token }
    json_response(response, :created)
  end

  def show
    user_data = current_user.as_json(except: [:password_digest, :created_at, :updated_at, :spotify_access_token, :spotify_refresh_token])
    user_data[:reviews_count] = current_user.reviews.count
    user_data[:bands_count] = current_user.bands.count
    user_data[:spotify_connected] = current_user.spotify_access_token.present?
    json_response(user_data)
  end

  def recently_played
    spotify_service = SpotifyService.new(current_user)
    result = spotify_service.recently_played(limit: params[:limit] || 20)
    
    if result[:error]
      render json: { error: result[:error] }, status: :bad_request
    else
      render json: result
    end
  end


  def profile_by_username
    user = User.find_by!(username: params[:username].downcase)
    reviews = user.reviews.includes(:band).order(created_at: :desc)
    bands = user.bands.order(:name)
    
    user_data = {
      id: user.id,
      username: user.username,
      email: user.email,
      reviews_count: reviews.count,
      bands_count: bands.count,
      reviews: reviews.map { |review| review_json(review) },
      bands: bands.map { |band| band_summary_json(band) }
    }
    
    json_response(user_data)
  end

  private

  def user_params
    params.permit(:username, :email, :password, :password_confirmation)
  end

  def review_json(review)
    {
      id: review.id,
      song_link: review.song_link,
      band_name: review.band_name,
      song_name: review.song_name,
      artwork_url: review.artwork_url,
      review_text: review.review_text,
      overall_rating: review.overall_rating,
      liked_aspects: review.liked_aspects_array,
      band: {
        id: review.band.id,
        slug: review.band.slug,
        name: review.band.name,
        location: review.band.location,
        spotify_link: review.band.spotify_link,
        bandcamp_link: review.band.bandcamp_link,
        apple_music_link: review.band.apple_music_link,
        youtube_music_link: review.band.youtube_music_link,
        about: review.band.about,
        profile_picture_url: review.band.profile_picture.attached? ? url_for(review.band.profile_picture) : nil
      },
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end

  def band_summary_json(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      profile_picture_url: band.profile_picture.attached? ? url_for(band.profile_picture) : nil,
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?
    }
  end
end
