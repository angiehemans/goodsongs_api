class Auth::InstagramController < ApplicationController
  skip_before_action :authenticate_request, only: [:callback]

  def authorize
    state = Rails.application.message_verifier(:social_oauth).generate(
      { user_id: current_user.id },
      expires_in: 10.minutes
    )
    url = InstagramOauthService.new.authorize_url(state: state)
    json_response({ authorize_url: url })
  end

  def callback
    state_data = Rails.application.message_verifier(:social_oauth).verify(params[:state])
    user = User.find(state_data[:user_id])
    service = InstagramOauthService.new

    # Exchange code for short-lived token
    token_data = service.exchange_code(code: params[:code])
    short_lived_token = token_data["access_token"]

    # Exchange for long-lived token
    long_lived_data = service.exchange_for_long_lived_token(short_lived_token: short_lived_token)
    access_token = long_lived_data["access_token"]
    expires_in = long_lived_data["expires_in"]

    # Fetch profile
    profile = service.fetch_profile(token: access_token)

    # Upsert connected account
    account = user.connected_accounts.find_or_initialize_by(platform: "instagram")
    account.update!(
      access_token: access_token,
      platform_user_id: profile["id"],
      platform_username: profile["username"],
      account_type: profile["account_type"],
      token_expires_at: expires_in ? Time.current + expires_in.to_i.seconds : nil,
      needs_reauth: false
    )

    frontend_url = ENV.fetch("FRONTEND_URL", "https://goodsongs.app")
    redirect_to "#{frontend_url}/settings/connections?status=success&platform=instagram", allow_other_host: true
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    frontend_url = ENV.fetch("FRONTEND_URL", "https://goodsongs.app")
    redirect_to "#{frontend_url}/settings/connections?status=error&platform=instagram", allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("Instagram OAuth error: #{e.message}")
    frontend_url = ENV.fetch("FRONTEND_URL", "https://goodsongs.app")
    redirect_to "#{frontend_url}/settings/connections?status=error&platform=instagram", allow_other_host: true
  end
end
