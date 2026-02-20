class ReviewComment < ApplicationRecord
  belongs_to :user
  belongs_to :review
  has_many :review_comment_likes, dependent: :destroy
  has_many :likers, through: :review_comment_likes, source: :user
  has_many :mentions, as: :mentionable, dependent: :destroy

  validates :body, presence: true, length: { maximum: 300 }

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }

  # Process mentions after saving
  after_save :process_mentions, if: :saved_change_to_body?

  def likes_count
    review_comment_likes.count
  end

  def liked_by?(user)
    return false unless user
    review_comment_likes.exists?(user_id: user.id)
  end

  private

  def process_mentions
    MentionService.new(body, mentioner: user, mentionable: self).sync_mentions
  end
end
