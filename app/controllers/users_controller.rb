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
    user_data = current_user.as_json(except: [:password_digest, :created_at, :updated_at])
    user_data[:reviews_count] = current_user.reviews.count
    json_response(user_data)
  end


  def profile_by_username
    user = User.find_by!(username: params[:username].downcase)
    reviews = user.reviews.includes(:band).order(created_at: :desc)
    
    user_data = {
      id: user.id,
      username: user.username,
      email: user.email,
      reviews_count: reviews.count,
      reviews: reviews.map { |review| review_json(review) }
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
        name: review.band.name
      },
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end
end
