# frozen_string_literal: true

class Scrobble < ApplicationRecord
  belongs_to :user
  belongs_to :track, optional: true

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
  validates :duration_ms, presence: true, numericality: { greater_than_or_equal_to: 30_000 }
  validates :played_at, presence: true
  validates :source_app, presence: true, length: { maximum: 100 }
  validates :source_device, length: { maximum: 100 }, allow_nil: true
  validates :preferred_artwork_url, length: { maximum: 2000 }, allow_nil: true

  validate :played_at_not_in_future
  validate :played_at_within_14_days

  # Scopes for querying
  scope :recent, -> { order(played_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :pending_enrichment, -> { where(metadata_status: :pending) }
  scope :since, ->(time) { where('played_at > ?', time) }
  scope :until_time, ->(time) { where('played_at < ?', time) }

  # Check for duplicate scrobble (same track/artist/played_at within 30 seconds)
  def self.duplicate?(user_id:, track_name:, artist_name:, played_at:)
    where(user_id: user_id, track_name: track_name, artist_name: artist_name)
      .where('played_at BETWEEN ? AND ?', played_at - 30.seconds, played_at + 30.seconds)
      .exists?
  end

  # Returns the artwork URL to display: preferred if set, otherwise album cover art
  def effective_artwork_url
    preferred_artwork_url.presence || track&.album&.cover_art_url
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
end
