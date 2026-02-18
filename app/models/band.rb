class Band < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  has_many :albums, dependent: :destroy
  has_many :tracks, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :band_aliases, dependent: :destroy
  has_one_attached :profile_picture
  has_one_attached :cached_artist_image

  enum :source, { musicbrainz: 0, user_submitted: 1 }

  # Geocoding for band location
  geocoded_by :full_location
  after_validation :geocode, if: :should_geocode?

  # Fetch artist image when band is created or musicbrainz_id/lastfm_artist_name changes
  after_commit :fetch_artist_image_on_create, on: :create, if: :should_fetch_image_on_create?
  after_commit :fetch_artist_image, on: :update, if: :should_fetch_image_on_update?

  # Auto-detect image source when artist_image_url changes
  before_save :detect_artist_image_source, if: :artist_image_url_changed?

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false, scope: :user_id }, if: :user_submitted?
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-_]+\z/, message: "can only contain lowercase letters, numbers, hyphens, and underscores" }
  validates :spotify_link, format: { with: /\Ahttps:\/\/(open\.)?spotify\.com(\/|\z)/, message: "must be a valid Spotify URL" }, allow_blank: true
  validates :bandcamp_link, format: { with: /\Ahttps:\/\/[\w\-]+\.bandcamp\.com(\/|\z)/, message: "must be a valid Bandcamp URL" }, allow_blank: true
  validates :apple_music_link, format: { with: /\Ahttps:\/\/music\.apple\.com(\/|\z)/, message: "must be a valid Apple Music URL" }, allow_blank: true
  validates :youtube_music_link, format: { with: /\Ahttps:\/\/music\.youtube\.com(\/|\z)/, message: "must be a valid YouTube Music URL" }, allow_blank: true
  validates :city, length: { maximum: 100 }, allow_blank: true
  validates :region, length: { maximum: 100 }, allow_blank: true

  before_validation :normalize_links
  before_validation :generate_slug
  
  scope :user_created, -> { where.not(user_id: nil) }
  scope :auto_generated, -> { where(user_id: nil) }
  scope :verified, -> { where(verified: true) }
  scope :canonical, -> { where(source: :musicbrainz) }
  scope :user_contributed, -> { where(source: :user_submitted) }
  scope :search_by_name, ->(query) {
    where("name % ?", query)
      .order(Arel.sql("similarity(name, #{connection.quote(query)}) DESC"))
  }
  
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

  # Resolved artist image URL - prefers cached version, falls back to external
  def resolved_artist_image_url
    # User-uploaded profile picture takes priority
    return profile_picture_url if profile_picture.attached?

    # Use cached image if available
    if cached_artist_image.attached?
      return cached_artist_image_url
    end

    # Queue caching if we have an external URL from a cacheable source
    if artist_image_url.present?
      source = artist_image_source.presence || ImageCachingService.detect_source(artist_image_url)
      if ImageCachingService.cacheable_source?(source)
        ImageCachingService.cache_image(
          record: self,
          attribute: :artist_image,
          url: artist_image_url,
          source: source
        )
      end
    end

    # Return external URL for now
    artist_image_url
  end

  def cached_artist_image_url
    return nil unless cached_artist_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      cached_artist_image,
      **active_storage_url_options
    )
  end

  def profile_picture_url
    return nil unless profile_picture.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      profile_picture,
      **active_storage_url_options
    )
  end

  private

  def active_storage_url_options
    if ENV['API_URL'].present?
      uri = URI.parse(ENV['API_URL'])
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
    else
      Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
    end
  end

  def detect_artist_image_source
    return if artist_image_url.blank?
    return if artist_image_source.present? # Don't override if explicitly set

    self.artist_image_source = ImageCachingService.detect_source(artist_image_url)
  end

  # Normalize links to ensure consistent format
  def normalize_links
    self.bandcamp_link = normalize_url(bandcamp_link, 'bandcamp.com')
    self.spotify_link = normalize_url(spotify_link, 'spotify.com')
    self.apple_music_link = normalize_url(apple_music_link, 'apple.com')
    self.youtube_music_link = normalize_url(youtube_music_link, 'youtube.com')
  end

  def normalize_url(url, domain)
    return nil if url.blank?

    url = url.strip

    # Add https:// if no protocol specified
    unless url.match?(/\Ahttps?:\/\//i)
      url = "https://#{url}"
    end

    # Upgrade http to https
    url = url.sub(/\Ahttp:\/\//i, 'https://')

    url
  end

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
