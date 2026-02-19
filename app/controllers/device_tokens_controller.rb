# frozen_string_literal: true

class DeviceTokensController < ApplicationController
  before_action :authenticate_request

  # POST /device_tokens
  # Register a device token for push notifications
  def create
    token = current_user.device_tokens.find_or_initialize_by(
      token: device_token_params[:token]
    )
    token.platform = device_token_params[:platform]
    token.last_used_at = Time.current

    if token.save
      json_response({ message: 'Device registered successfully' })
    else
      render_error(token.errors.full_messages.join(', '), :unprocessable_entity)
    end
  end

  # DELETE /device_tokens
  # Unregister a device token (e.g., on logout)
  def destroy
    token = current_user.device_tokens.find_by(token: params[:token])
    token&.destroy

    json_response({ message: 'Device unregistered successfully' })
  end

  private

  def device_token_params
    params.require(:device_token).permit(:token, :platform)
  end
end
