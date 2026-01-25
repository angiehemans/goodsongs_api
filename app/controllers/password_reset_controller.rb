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
        user.generate_password_reset_token!
        UserMailerJob.perform_later(user.id, :password_reset)
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

    user = User.find_by(password_reset_token: token)

    if user && user.password_reset_token_valid?
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

    # Generate new auth token for the user
    auth_token = JsonWebToken.encode(user_id: user.id)

    json_response({
      message: 'Password reset successfully',
      auth_token: auth_token
    })
  rescue PasswordResetService::TokenInvalid
    json_response({ error: 'Invalid reset token' }, :bad_request)
  rescue PasswordResetService::TokenExpired
    json_response({ error: 'Reset token has expired' }, :gone)
  rescue PasswordResetService::InvalidPassword => e
    json_response({ error: 'Invalid password', details: e.errors }, :unprocessable_entity)
  end
end
