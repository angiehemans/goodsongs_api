class PostCommentLike < ApplicationRecord
  belongs_to :user
  belongs_to :post_comment

  validates :user_id, uniqueness: { scope: :post_comment_id }
end
