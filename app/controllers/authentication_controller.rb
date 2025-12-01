# app/controllers/authentication_controller.rb
class AuthenticationController < ApplicationController
  skip_before_action :authenticate_request, only: [:authenticate]
  skip_before_action :require_onboarding_completed, only: [:authenticate]

  def authenticate
    auth_token = AuthenticateUser.new(auth_params[:email], auth_params[:password]).call
    json_response(auth_token: auth_token)
  end

  private

  def auth_params
    params.permit(:email, :password)
  end
end
