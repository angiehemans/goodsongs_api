class RefreshSocialTokensJob < ApplicationJob
  queue_as :default

  def perform
    ConnectedAccount.needing_refresh.find_each do |account|
      refresh_account(account)
    rescue StandardError => e
      Rails.logger.error("Token refresh failed for ConnectedAccount##{account.id}: #{e.message}")
      account.update!(needs_reauth: true)
      Notification.notify_social_reauth_needed(user: account.user, account: account)
    end
  end

  private

  def refresh_account(account)
    service = case account.platform
              when "threads" then ThreadsOauthService.new
              when "instagram" then InstagramOauthService.new
              else return
              end

    result = service.refresh_token(token: account.access_token)

    if result["access_token"].present?
      account.update!(
        access_token: result["access_token"],
        token_expires_at: result["expires_in"] ? Time.current + result["expires_in"].to_i.seconds : nil,
        needs_reauth: false
      )
    else
      account.update!(needs_reauth: true)
      Notification.notify_social_reauth_needed(user: account.user, account: account)
    end
  end
end
