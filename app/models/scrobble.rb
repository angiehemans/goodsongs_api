# frozen_string_literal: true

class Scrobble < ApplicationRecord
  belongs_to :user
  belongs_to :track, optional: true
  has_one_attached :album_art

  # Metadata status enum matching PRD spec
  enum :metadata_status, {
    pending: 0,
    enriched: 1,
    not_found: 2,
    failed: 3
  }

  # Enqueue enrichment job after creation
  after_create_commit :enqueue_enrichment_job

  # Validations per PRD spec
  validates :track_name, presence: true, length: { maximum: 500 }
  validates :artist_name, presence: true, length: { maximum: 500 }
  validates :album_name, length: { maximum: 500 }, allow_nil: true
  # Duration not required for Last.fm tracks (they don't provide it)
  validates :duration_ms, presence: true, numericality: { greater_than_or_equal_to: 30_000 }, unless: :from_lastfm?
  validates :played_at, presence: true
  validates :source_app, presence: true, length: { maximum: 100 }
  validates :source_device, length: { maximum: 100 }, allow_nil: true
  validates :preferred_artwork_url, length: { maximum: 2000 }, allow_nil: true
  validates :album_artist, length: { maximum: 500 }, allow_nil: true
  validates :genre, length: { maximum: 100 }, allow_nil: true
  validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1800, less_than_or_equal_to: 2100 }, allow_nil: true
  validates :artwork_uri, length: { maximum: 2000 }, allow_nil: true
  validates :lastfm_url, length: { maximum: 2000 }, allow_nil: true
  validate :album_art_format_and_size

  validate :played_at_not_in_future
  # Last.fm tracks may be older than 14 days
  validate :played_at_within_14_days, unless: :from_lastfm?

  # Scopes for querying
  scope :recent, -> { order(played_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :pending_enrichment, -> { where(metadata_status: :pending) }
  scope :since, ->(time) { where('played_at > ?', time) }
  scope :until_time, ->(time) { where('played_at < ?', time) }
  scope :from_lastfm, -> { where(source_app: 'lastfm') }

  # Check if this scrobble was converted from Last.fm
  def from_lastfm?
    source_app == 'lastfm'
  end

  # Check for duplicate scrobble (same track/artist/played_at within 30 seconds)
  def self.duplicate?(user_id:, track_name:, artist_name:, played_at:)
    where(user_id: user_id, track_name: track_name, artist_name: artist_name)
      .where('played_at BETWEEN ? AND ?', played_at - 30.seconds, played_at + 30.seconds)
      .exists?
  end

  # Returns the artwork URL to display with priority:
  # 1. artwork_uri (external URL from Android, e.g., Spotify CDN)
  # 2. album_art (uploaded base64 bitmap via Active Storage)
  # 3. preferred_artwork_url (user-selected override)
  # 4. track.album.resolved_cover_art_url (cached or external, triggers caching)
  def effective_artwork_url
    artwork_uri.presence ||
      album_art_url ||
      preferred_artwork_url.presence ||
      track&.album&.resolved_cover_art_url
  end

  # Get the URL for the attached album_art image
  def album_art_url
    return nil unless album_art.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      album_art,
      **active_storage_url_options
    )
  end

  def active_storage_url_options
    if ENV['API_URL'].present?
      uri = URI.parse(ENV['API_URL'])
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
    else
      Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
    end
  end

  # Check if user has uploaded artwork (Active Storage attachment)
  def has_uploaded_artwork?
    album_art.attached?
  end

  # Check if user has set a preferred artwork (overriding album art)
  def has_preferred_artwork?
    preferred_artwork_url.present?
  end

  private

  def enqueue_enrichment_job
    ScrobbleEnrichmentJob.perform_later(id)
  end

  def played_at_not_in_future
    return unless played_at.present? && played_at > Time.current

    errors.add(:played_at, 'cannot be in the future')
  end

  def played_at_within_14_days
    return unless played_at.present? && played_at < 14.days.ago

    errors.add(:played_at, 'must be within the last 14 days')
  end

  def album_art_format_and_size
    return unless album_art.attached?

    allowed_types = %w[image/jpeg image/png image/webp]
    unless allowed_types.include?(album_art.content_type)
      errors.add(:album_art, 'must be a JPEG, PNG, or WebP image')
    end

    if album_art.byte_size > 5.megabytes
      errors.add(:album_art, 'must be less than 5MB')
    end
  end
end
