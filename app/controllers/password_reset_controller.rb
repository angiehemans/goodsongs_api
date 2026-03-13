class PasswordResetController < ApplicationController
  skip_before_action :authenticate_request
  skip_before_action :require_onboarding_completed

  # POST /password/forgot
  # Request password reset email
  def create
    email = params[:email]&.downcase

    if email.blank?
      return json_response({ error: 'Email is required' }, :bad_request)
    end

    user = User.find_by(email: email)

    # Always return success to prevent email enumeration
    # But only send email if user exists and is not disabled
    if user && !user.disabled?
      if user.can_request_password_reset?
        # Update rate limit timestamp (token is generated on-demand by Rails 8)
        user.update!(password_reset_sent_at: Time.current)
        begin
          UserMailerJob.perform_later(user.id, :password_reset)
        rescue StandardError => e
          Rails.logger.error("Failed to enqueue password reset email for user #{user.id}: #{e.message}")
        end
      end
    end

    json_response({
      message: 'If an account exists with this email, a password reset link has been sent'
    })
  end

  # GET /password/validate-token
  # Check if a password reset token is valid (for frontend UX)
  def validate_token
    token = params[:token]

    if token.blank?
      return json_response({ valid: false, error: 'Token is required' }, :bad_request)
    end

    # Rails 8's find_by_token_for handles expiration automatically
    user = User.find_by_token_for(:password_reset, token)

    if user
      json_response({ valid: true })
    else
      json_response({ valid: false, error: 'Token is invalid or expired' })
    end
  end

  # POST /password/reset
  # Reset password with token
  def update
    service = PasswordResetService.new(
      params[:token],
      params[:password],
      params[:password_confirmation]
    )

    user = service.call

    # Generate new auth token and refresh token for the user
    # (all previous sessions were revoked during password reset)
    auth_token = JsonWebToken.encode(user_id: user.id)
    raw_refresh_token, _refresh_token = RefreshToken.generate_for(user, request: request)

    json_response({
      message: 'Password reset successfully',
      auth_token: auth_token,
      refresh_token: raw_refresh_token,
      expires_in: JsonWebToken::ACCESS_TOKEN_EXPIRATION.to_i
    })
  rescue PasswordResetService::TokenInvalid
    json_response({ error: 'Invalid reset token' }, :bad_request)
  rescue PasswordResetService::TokenExpired
    json_response({ error: 'Reset token has expired' }, :gone)
  rescue PasswordResetService::InvalidPassword => e
    json_response({ error: 'Invalid password', details: e.errors }, :unprocessable_entity)
  end
end
