class Review < ApplicationRecord
  belongs_to :band
  belongs_to :user

  # Scope to exclude reviews from disabled users
  scope :from_active_users, -> { joins(:user).where(users: { disabled: false }) }

  validates :song_link, presence: true
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
end
