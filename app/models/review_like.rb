class ReviewLike < ApplicationRecord
  belongs_to :user
  belongs_to :review

  validates :user_id, uniqueness: { scope: :review_id, message: 'has already liked this review' }
end
