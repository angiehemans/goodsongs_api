class Mention < ApplicationRecord
  belongs_to :user  # The mentioned user
  belongs_to :mentioner, class_name: 'User'
  belongs_to :mentionable, polymorphic: true

  validates :user_id, uniqueness: {
    scope: [:mentionable_type, :mentionable_id],
    message: 'has already been mentioned in this content'
  }

  # Don't allow self-mentions
  validate :cannot_mention_self

  after_create_commit :send_notification

  private

  def cannot_mention_self
    errors.add(:user, "can't mention yourself") if user_id == mentioner_id
  end

  def send_notification
    # Skip if the mentioned user is the review author being mentioned in a comment on their own review
    # They already get a review_comment notification which will include the mention
    return if duplicate_comment_notification?

    Notification.notify_mention(
      mentioned_user: user,
      mentioner: mentioner,
      mentionable: mentionable
    )
  end

  # Check if this would duplicate a review_comment notification
  def duplicate_comment_notification?
    return false unless mentionable.is_a?(ReviewComment)

    # If the mentioned user is the review author, they already get a comment notification
    mentionable.review.user_id == user_id
  end
end
