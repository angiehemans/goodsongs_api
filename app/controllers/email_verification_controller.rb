class EmailVerificationController < ApplicationController
  skip_before_action :authenticate_request, only: [:confirm]
  skip_before_action :require_onboarding_completed

  # POST /email/resend-confirmation
  # Requires authentication
  def resend_confirmation
    if current_user.email_confirmed?
      return json_response({ error: 'Email already confirmed' }, :bad_request)
    end

    unless current_user.can_resend_confirmation?
      seconds_remaining = 60 - (Time.current - current_user.email_confirmation_sent_at).to_i
      return json_response({
        error: 'Please wait before requesting another confirmation email',
        retry_after: [seconds_remaining, 0].max
      }, :too_many_requests)
    end

    current_user.generate_email_confirmation_token!
    UserMailerJob.perform_later(current_user.id, :confirmation)

    json_response({
      message: 'Confirmation email sent',
      can_resend_confirmation: false,
      retry_after: 60
    })
  end

  # POST /email/confirm
  # Public endpoint (no auth required)
  def confirm
    service = EmailConfirmationService.new(params[:token])
    user = service.call

    # Generate new auth token for the confirmed user
    auth_token = JsonWebToken.encode(user_id: user.id)

    json_response({
      message: 'Email confirmed successfully',
      auth_token: auth_token
    })
  rescue EmailConfirmationService::TokenInvalid
    json_response({ error: 'Invalid confirmation token' }, :bad_request)
  rescue EmailConfirmationService::TokenExpired
    json_response({ error: 'Confirmation token has expired' }, :gone)
  rescue EmailConfirmationService::AlreadyConfirmed
    json_response({ error: 'Email already confirmed' }, :bad_request)
  end
end
