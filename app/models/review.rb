class Review < ApplicationRecord
  belongs_to :band, counter_cache: true
  belongs_to :user, counter_cache: true
  belongs_to :track, optional: true
  has_many :review_likes, dependent: :destroy
  has_many :likers, through: :review_likes, source: :user
  has_many :review_comments, dependent: :destroy
  has_many :commenters, through: :review_comments, source: :user
  has_many :mentions, as: :mentionable, dependent: :destroy

  GENRES = %w[
    Rock Pop Hip-Hop Jazz Blues Country R&B Soul Funk Electronic
    Metal Punk Indie Alternative Folk Classical Reggae Latin
    Ambient Experimental
  ].freeze

  # Scope to exclude reviews from disabled users
  scope :from_active_users, -> { joins(:user).where(users: { disabled: false }) }

  def likes_count
    self[:review_likes_count] || review_likes.size
  end

  def comments_count
    self[:review_comments_count] || review_comments.size
  end

  def liked_by?(user)
    return false unless user
    review_likes.any? { |like| like.user_id == user.id }
  end

  validates :band_name, presence: true
  validates :song_name, presence: true
  validates :review_text, presence: true
  
  LIKED_ASPECTS = %w[Guitar Vocals Lyrics Drums Bass Production Melody Rhythm Energy Creativity].freeze
  
  def liked_aspects_array
    return [] if liked_aspects.blank?
    
    # Handle both old string format and new JSON format
    begin
      parsed = JSON.parse(liked_aspects)
      # If it's an array of objects, return as is
      # If it's an array of strings, convert to objects
      if parsed.is_a?(Array)
        if parsed.first.is_a?(String)
          # Convert old string format to object format
          parsed.map { |aspect| { 'name' => aspect } }
        else
          parsed
        end
      else
        []
      end
    rescue JSON::ParserError
      # Fallback for old comma-separated format
      liked_aspects.split(',').map { |aspect| { 'name' => aspect.strip } }
    end
  end
  
  def liked_aspects_array=(aspects)
    if aspects.is_a?(Array)
      # Handle array of objects or array of strings
      normalized = aspects.map do |aspect|
        if aspect.is_a?(String)
          { 'name' => aspect }
        elsif aspect.is_a?(Hash)
          aspect.stringify_keys
        else
          aspect
        end
      end
      self.liked_aspects = normalized.to_json
    else
      self.liked_aspects = aspects.to_s
    end
  end

  # Process mentions after saving
  after_save :process_mentions, if: :saved_change_to_review_text?

  # Auto-post to connected social platforms
  after_create_commit :enqueue_social_auto_posts

  private

  def process_mentions
    MentionService.new(review_text, mentioner: user, mentionable: self).sync_mentions
  end

  def enqueue_social_auto_posts
    user.connected_accounts.each do |account|
      next unless account.platform == "threads"
      next unless account.should_auto_post?("review")

      SocialAutoPostJob.perform_later("Review", id, account.platform)
    end
  end
end
