# app/controllers/concerns/authenticable.rb
module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
    attr_reader :current_user
  end

  private

  def authenticate_request
    @current_user = AuthorizeApiRequest.new(request.headers).call[:user]
  end

  def authenticate_request_optional
    @current_user = AuthorizeApiRequest.new(request.headers).call[:user]
  rescue ExceptionHandler::AuthenticationError, ExceptionHandler::MissingToken,
         ExceptionHandler::InvalidToken, ExceptionHandler::ExpiredToken
    @current_user = nil
  end

  # Get authenticated user without raising error (for optional auth endpoints)
  def authenticated_user
    return @current_user if defined?(@current_user) && @current_user

    AuthorizeApiRequest.new(request.headers).call[:user]
  rescue ExceptionHandler::AuthenticationError, ExceptionHandler::MissingToken,
         ExceptionHandler::InvalidToken, ExceptionHandler::ExpiredToken
    nil
  end
end
