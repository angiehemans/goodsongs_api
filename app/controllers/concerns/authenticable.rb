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
    begin
      @current_user = AuthorizeApiRequest.new(request.headers).call[:user]
    rescue
      @current_user = nil
    end
  end

  # Get authenticated user without raising error (for optional auth endpoints)
  def authenticated_user
    return @current_user if defined?(@current_user) && @current_user
    begin
      AuthorizeApiRequest.new(request.headers).call[:user]
    rescue
      nil
    end
  end
end
