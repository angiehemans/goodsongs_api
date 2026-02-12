# app/controllers/authentication_controller.rb
class AuthenticationController < ApplicationController
  skip_before_action :authenticate_request, only: [:authenticate, :refresh]
  skip_before_action :require_onboarding_completed, only: [:authenticate, :refresh, :logout]

  # POST /login
  def authenticate
    auth = AuthenticateUser.new(
      auth_params[:email],
      auth_params[:password],
      request: request,
      device_name: auth_params[:device_name]
    ).call

    json_response(
      auth_token: auth.access_token,
      refresh_token: auth.refresh_token,
      expires_in: JsonWebToken::ACCESS_TOKEN_EXPIRATION.to_i,
      user: UserSerializer.profile_data(auth.user)
    )
  end

  # POST /auth/refresh
  # Exchange a refresh token for a new access token
  def refresh
    refresh_token_param = params[:refresh_token]

    if refresh_token_param.blank?
      return json_response({ error: 'Refresh token is required' }, :bad_request)
    end

    refresh_token = RefreshToken.find_by_token(refresh_token_param)

    if refresh_token.nil?
      return json_response({ error: 'Invalid or expired refresh token', code: 'invalid_refresh_token' }, :unauthorized)
    end

    user = refresh_token.user

    if user.disabled?
      refresh_token.revoke!
      return json_response({ error: Message.account_disabled, code: 'account_disabled' }, :unauthorized)
    end

    # Generate new access token
    access_token = JsonWebToken.encode(user_id: user.id)

    # Optionally rotate refresh token for extra security
    # Uncomment to enable refresh token rotation:
    # refresh_token.revoke!
    # new_raw_token, _new_refresh_token = RefreshToken.generate_for(user, request: request)

    json_response(
      auth_token: access_token,
      expires_in: JsonWebToken::ACCESS_TOKEN_EXPIRATION.to_i
      # refresh_token: new_raw_token  # Include if rotating
    )
  end

  # POST /auth/logout
  # Revoke the current refresh token
  def logout
    refresh_token_param = params[:refresh_token]

    if refresh_token_param.present?
      refresh_token = RefreshToken.find_by_token(refresh_token_param)
      refresh_token&.revoke!
    end

    json_response(message: 'Logged out successfully')
  end

  # POST /auth/logout-all
  # Revoke all refresh tokens for the current user (logout from all devices)
  def logout_all
    RefreshToken.revoke_all_for_user(current_user)
    json_response(message: 'Logged out from all devices successfully')
  end

  # GET /auth/sessions
  # List active sessions for the current user
  def sessions
    active_tokens = current_user.refresh_tokens.active.order(created_at: :desc)

    json_response(
      sessions: active_tokens.map do |token|
        {
          id: token.id,
          device_name: token.device_name,
          device_type: token.device_type,
          ip_address: token.ip_address,
          created_at: token.created_at,
          expires_at: token.expires_at,
          current: token.token_digest == RefreshToken.digest(params[:current_refresh_token])
        }
      end
    )
  end

  # DELETE /auth/sessions/:id
  # Revoke a specific session
  def revoke_session
    token = current_user.refresh_tokens.active.find(params[:id])
    token.revoke!
    json_response(message: 'Session revoked successfully')
  end

  private

  def auth_params
    params.permit(:email, :password, :device_name)
  end
end
