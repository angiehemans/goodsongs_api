class PostComment < ApplicationRecord
  belongs_to :user, optional: true  # Nullable for anonymous comments
  belongs_to :post
  has_many :post_comment_likes, dependent: :destroy
  has_many :likers, through: :post_comment_likes, source: :user
  has_many :mentions, as: :mentionable, dependent: :destroy

  validates :body, presence: true, length: { maximum: 300 }
  validates :guest_name, presence: true, if: :anonymous?
  validates :guest_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :anonymous?

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }

  before_create :generate_claim_token, if: :anonymous?
  after_save :process_mentions, if: -> { saved_change_to_body? && user.present? }

  def anonymous?
    user_id.nil? && claimed_at.nil?
  end

  def claim!(new_user)
    return false unless anonymous?
    return false if claim_token.blank?

    update!(
      user: new_user,
      guest_name: nil,
      guest_email: nil,
      claim_token: nil,
      claimed_at: Time.current
    )
  end

  def likes_count
    post_comment_likes.count
  end

  def liked_by?(user)
    return false unless user
    post_comment_likes.exists?(user_id: user.id)
  end

  private

  def generate_claim_token
    self.claim_token = SecureRandom.urlsafe_base64(32)
  end

  def process_mentions
    MentionService.new(body, mentioner: user, mentionable: self).sync_mentions
  end
end
