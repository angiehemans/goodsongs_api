# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Authenticable
  include ExceptionHandler

  private

  def json_response(object, status = :ok)
    render json: object, status: status
  end
end
