class ConnectedAccount < ApplicationRecord
  encrypts :access_token

  belongs_to :user

  PLATFORMS = %w[threads instagram].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :platform, uniqueness: { scope: :user_id }

  scope :threads, -> { where(platform: "threads") }
  scope :instagram, -> { where(platform: "instagram") }
  scope :needing_refresh, -> {
    where("token_expires_at < ?", 14.days.from_now)
      .where(needs_reauth: false)
  }

  def should_auto_post?(content_type)
    return false if needs_reauth?
    return false unless auto_post_eligible?

    case content_type.to_s
    when "review" then auto_post_recommendations?
    when "post" then auto_post_band_posts?
    when "event" then auto_post_events?
    else false
    end
  end

  def auto_post_eligible?
    return false if platform == "instagram" && account_type == "PERSONAL"
    true
  end
end
