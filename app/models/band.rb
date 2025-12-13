class Band < ApplicationRecord
  belongs_to :user, optional: true
  has_many :reviews, dependent: :destroy
  has_many :events, dependent: :destroy
  has_one_attached :profile_picture

  # Geocoding for band location
  geocoded_by :full_location
  after_validation :geocode, if: :should_geocode?

  # Fetch Spotify artist image when spotify_link changes
  after_commit :fetch_spotify_image, if: :spotify_link_changed_and_present?

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-_]+\z/, message: "can only contain lowercase letters, numbers, hyphens, and underscores" }
  validates :spotify_link, format: { with: /\Ahttps:\/\/(open\.)?spotify\.com\//, message: "must be a valid Spotify URL" }, allow_blank: true
  validates :bandcamp_link, format: { with: /\Ahttps:\/\/.*\.bandcamp\.com\//, message: "must be a valid Bandcamp URL" }, allow_blank: true
  validates :apple_music_link, format: { with: /\Ahttps:\/\/music\.apple\.com\//, message: "must be a valid Apple Music URL" }, allow_blank: true
  validates :youtube_music_link, format: { with: /\Ahttps:\/\/music\.youtube\.com\//, message: "must be a valid YouTube Music URL" }, allow_blank: true
  validates :city, length: { maximum: 100 }, allow_blank: true
  validates :region, length: { maximum: 100 }, allow_blank: true

  before_validation :generate_slug
  
  scope :user_created, -> { where.not(user_id: nil) }
  scope :auto_generated, -> { where(user_id: nil) }
  
  def user_owned?
    user_id.present?
  end
  
  def auto_generated?
    user_id.nil?
  end
  
  def to_param
    slug
  end

  # Full location string for geocoding
  def full_location
    [city, region].compact.reject(&:blank?).join(', ')
  end

  # Location display string
  def location
    full_location.presence
  end

  # Check if band has a location set
  def has_location?
    city.present? || region.present?
  end

  # Extract Spotify artist ID from the spotify_link
  def spotify_artist_id
    SpotifyArtistService.extract_artist_id(spotify_link)
  end

  private

  def spotify_link_changed_and_present?
    saved_change_to_spotify_link? && spotify_link.present?
  end

  def fetch_spotify_image
    FetchSpotifyImageJob.perform_later(id)
  end

  # Only geocode if location fields changed and we have location data
  def should_geocode?
    (city_changed? || region_changed?) && full_location.present?
  end
  
  def generate_slug
    return if name.blank?
    
    # If user provided a custom slug, normalize it but don't auto-generate
    if slug.present? && !slug_should_be_auto_generated?
      self.slug = normalize_slug(slug)
      return
    end
    
    # Auto-generate slug from name
    base_slug = normalize_slug(name)
    base_slug = 'band' if base_slug.blank?
    
    # Check if base slug is available
    if slug.blank? || slug_should_be_auto_generated?
      candidate_slug = base_slug
      counter = 1
      
      while Band.where(slug: candidate_slug).where.not(id: id).exists?
        candidate_slug = "#{base_slug}-#{id || counter}"
        counter += 1
      end
      
      self.slug = candidate_slug
    end
  end
  
  def normalize_slug(text)
    text.downcase.gsub(/[^a-z0-9\-_]/, '-').gsub(/-+/, '-').gsub(/^-+|-+$/, '')
  end
  
  def slug_should_be_auto_generated?
    # Auto-generate if slug is blank or if name changed and slug wasn't manually set
    slug.blank? || (name_changed? && !slug_changed?)
  end
end
