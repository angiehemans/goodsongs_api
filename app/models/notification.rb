class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  TYPES = %w[new_follower new_review review_like review_comment].freeze

  validates :notification_type, presence: true, inclusion: { in: TYPES }

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def self.notify_new_follower(followed_user:, follower:)
    create!(
      user: followed_user,
      notification_type: 'new_follower',
      actor: follower,
      notifiable: follower
    )
  end

  def self.notify_new_review(band_owner:, review:)
    return if band_owner.nil?
    # Don't notify if the reviewer is the band owner
    return if review.user_id == band_owner.id

    create!(
      user: band_owner,
      notification_type: 'new_review',
      actor: review.user,
      notifiable: review
    )
  end

  def self.notify_review_like(review:, liker:)
    # Don't notify if the liker is the review author
    return if review.user_id == liker.id

    create!(
      user: review.user,
      notification_type: 'review_like',
      actor: liker,
      notifiable: review
    )
  end

  def self.notify_review_comment(review:, commenter:, comment:)
    # Don't notify if the commenter is the review author
    return if review.user_id == commenter.id

    create!(
      user: review.user,
      notification_type: 'review_comment',
      actor: commenter,
      notifiable: comment
    )
  end
end
