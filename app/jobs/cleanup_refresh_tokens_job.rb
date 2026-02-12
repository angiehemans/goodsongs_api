# frozen_string_literal: true

# Job to clean up old expired and revoked refresh tokens
# Run periodically (e.g., daily) via cron or scheduler
#
# Example with Sidekiq-Cron:
#   CleanupRefreshTokensJob.perform_later
#
# Example cron entry (daily at 3am):
#   0 3 * * * cd /path/to/app && bin/rails runner "CleanupRefreshTokensJob.perform_now"
#
class CleanupRefreshTokensJob < ApplicationJob
  queue_as :low

  def perform
    deleted_count = RefreshToken.cleanup_old_tokens(older_than: 7.days.ago)
    Rails.logger.info("[CleanupRefreshTokensJob] Deleted #{deleted_count} old refresh tokens")
  end
end
