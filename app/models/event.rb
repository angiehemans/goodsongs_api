class Event < ApplicationRecord
  belongs_to :user
  belongs_to :band, optional: true
  belongs_to :venue
  has_one_attached :image
  has_many :event_likes, dependent: :destroy
  has_many :likers, through: :event_likes, source: :user
  has_many :event_comments, dependent: :destroy
  has_many :page_views, as: :viewable, dependent: :destroy

  scope :upcoming, -> { where('event_date > ?', Time.current).order(event_date: :asc) }
  scope :past, -> { where('event_date <= ?', Time.current).order(event_date: :desc) }
  scope :active, -> { where(disabled: false) }
  scope :from_active_bands, -> { joins(:band).where(bands: { disabled: false }) }
  scope :visible, -> { left_joins(:band).where(band_id: nil).or(left_joins(:band).where(bands: { disabled: false })) }

  AGE_RESTRICTIONS = ['All Ages', '18+', '21+'].freeze

  def likes_count
    event_likes_count
  end

  def comments_count
    event_comments_count
  end

  def liked_by?(user)
    return false unless user
    event_likes.exists?(user_id: user.id)
  end

  validates :name, presence: true
  validates :event_date, presence: true
  validates :age_restriction, inclusion: { in: AGE_RESTRICTIONS }, allow_blank: true
end
