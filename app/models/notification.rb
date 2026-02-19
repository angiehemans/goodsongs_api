class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  TYPES = %w[new_follower new_review review_like review_comment].freeze

  validates :notification_type, presence: true, inclusion: { in: TYPES }

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  # Send push notification after creating in-app notification
  after_create_commit :send_push_notification

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

  private

  def send_push_notification
    title, body, data = push_notification_content
    return unless title && body

    SendPushNotificationJob.perform_later(
      user_id,
      title: title,
      body: body,
      data: data
    )
  end

  def push_notification_content
    actor_name = actor&.display_name || 'Someone'

    case notification_type
    when 'new_follower'
      [
        'New Follower',
        "#{actor_name} started following you",
        { type: 'new_follower', notification_id: id.to_s, actor_id: actor_id.to_s }
      ]
    when 'new_review'
      review = notifiable
      return [nil, nil, {}] unless review.is_a?(Review)

      [
        'New Review',
        "#{actor_name} reviewed #{review.song_name}",
        { type: 'new_review', notification_id: id.to_s, review_id: review.id.to_s }
      ]
    when 'review_like'
      review = notifiable
      return [nil, nil, {}] unless review.is_a?(Review)

      [
        'New Like',
        "#{actor_name} liked your review of #{review.song_name}",
        { type: 'review_like', notification_id: id.to_s, review_id: review.id.to_s }
      ]
    when 'review_comment'
      comment = notifiable
      return [nil, nil, {}] unless comment.is_a?(ReviewComment)

      review = comment.review
      comment_preview = comment.body.truncate(50)

      [
        'New Comment',
        "#{actor_name}: \"#{comment_preview}\"",
        { type: 'review_comment', notification_id: id.to_s, review_id: review.id.to_s, comment_id: comment.id.to_s }
      ]
    else
      [nil, nil, {}]
    end
  end
end
