class ReviewCommentLike < ApplicationRecord
  belongs_to :user
  belongs_to :review_comment

  validates :user_id, uniqueness: {
    scope: :review_comment_id,
    message: 'has already liked this comment'
  }
end
