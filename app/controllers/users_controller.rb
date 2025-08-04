# app/controllers/users_controller.rb
class UsersController < ApplicationController
  
  skip_before_action :authenticate_request, only: [:create, :profile_by_username]

  def create
    user = User.create!(user_params)
    auth_token = AuthenticateUser.new(user.email, user.password).call
    response = { message: Message.account_created, auth_token: auth_token }
    json_response(response, :created)
  end

  def show
    json_response(UserSerializer.profile_data(current_user))
  end

  def update
    if current_user.update(profile_params)
      json_response(UserSerializer.profile_data(current_user))
    else
      json_response({ errors: current_user.errors.full_messages }, :unprocessable_entity)
    end
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
    
    user_data = UserSerializer.public_profile(user).merge(
      reviews: reviews.map { |review| ReviewSerializer.full(review) },
      bands: bands.map { |band| BandSerializer.summary(band) }
    )
    
    json_response(user_data)
  end

  private

  def user_params
    params.permit(:username, :email, :password, :password_confirmation)
  end

  def profile_params
    params.permit(:about_me, :profile_image)
  end

end
