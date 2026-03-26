class SocialAutoPostJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError,
           wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  ALLOWED_TYPES = %w[Review Post Event].freeze

  def perform(postable_type, postable_id, platform)
    return unless ALLOWED_TYPES.include?(postable_type)

    postable = postable_type.constantize.find_by(id: postable_id)
    return unless postable

    account = postable.user.connected_accounts.find_by(platform: platform)
    return unless account
    return if account.needs_reauth?

    content_type = postable_type.downcase
    return unless account.should_auto_post?(content_type == "review" ? "review" : content_type)

    service = case platform
              when "threads" then ThreadsPostService.new
              when "instagram" then InstagramPostService.new
              else return
              end

    service.post(account, postable)
  rescue SocialPostService::ReauthRequired
    account.update!(needs_reauth: true)
    Notification.notify_social_reauth_needed(user: account.user, account: account)
  end
end
