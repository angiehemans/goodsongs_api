class Review < ApplicationRecord
  belongs_to :band
  belongs_to :user
  
  validates :song_link, presence: true
  validates :band_name, presence: true
  validates :song_name, presence: true
  validates :review_text, presence: true
  validates :overall_rating, presence: true, inclusion: { in: 1..3 }
  
  LIKED_ASPECTS = %w[Guitar Vocals Lyrics Drums Bass Production Melody Rhythm Energy Creativity].freeze
  
  def liked_aspects_array
    return [] if liked_aspects.blank?
    liked_aspects.split(',')
  end
  
  def liked_aspects_array=(aspects)
    self.liked_aspects = aspects.reject(&:blank?).join(',')
  end
end
