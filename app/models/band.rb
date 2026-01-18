class Band < ApplicationRecord
  belongs_to :user, optional: true
  has_many :reviews, dependent: :destroy
  has_many :events, dependent: :destroy
  has_one_attached :profile_picture

  # Geocoding for band location
  geocoded_by :full_location
  after_validation :geocode, if: :should_geocode?

  # Fetch artist image when band is created or musicbrainz_id/lastfm_artist_name changes
  after_commit :fetch_artist_image_on_create, on: :create, if: :should_fetch_image_on_create?
  after_commit :fetch_artist_image, on: :update, if: :should_fetch_image_on_update?

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

  # Last.fm URL for the artist
  def lastfm_url
    return nil unless lastfm_artist_name.present?
    "https://www.last.fm/music/#{ERB::Util.url_encode(lastfm_artist_name)}"
  end

  private

  def should_fetch_image_on_create?
    # Fetch image for auto-generated bands (no user) that don't have an image yet
    auto_generated? && artist_image_url.blank?
  end

  def should_fetch_image_on_update?
    # Fetch image if musicbrainz_id or lastfm_artist_name changed and we don't have an image
    (saved_change_to_musicbrainz_id? || saved_change_to_lastfm_artist_name?) &&
      (musicbrainz_id.present? || lastfm_artist_name.present?)
  end

  def fetch_artist_image_on_create
    FetchArtistImageJob.perform_later(id)
  end

  def fetch_artist_image
    FetchArtistImageJob.perform_later(id)
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
