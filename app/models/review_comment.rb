class ReviewComment < ApplicationRecord
  belongs_to :user
  belongs_to :review

  validates :body, presence: true, length: { maximum: 300 }

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
end
