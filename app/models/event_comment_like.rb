class EventCommentLike < ApplicationRecord
  belongs_to :user
  belongs_to :event_comment

  validates :user_id, uniqueness: { scope: :event_comment_id, message: 'has already liked this comment' }
end
