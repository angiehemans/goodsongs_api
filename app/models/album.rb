# frozen_string_literal: true

# Canonical album data from MusicBrainz
class Album < ApplicationRecord
  belongs_to :band, optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  has_many :tracks, dependent: :nullify
  has_one_attached :cached_cover_art

  enum :source, { musicbrainz: 0, user_submitted: 1 }

  validates :name, presence: true
  validates :musicbrainz_release_id, uniqueness: true, allow_nil: true
  validates :discogs_master_id, uniqueness: true, allow_nil: true
  validates :release_type, inclusion: {
    in: %w[album single ep compilation live remix soundtrack other],
    allow_nil: true
  }

  # Auto-detect image source when cover_art_url changes
  before_save :detect_cover_art_source, if: :cover_art_url_changed?

  # Queue caching job when cover art URL is set from a cacheable source
  after_commit :queue_cover_art_caching, if: :saved_change_to_cover_art_url?

  scope :search_by_name, ->(query) {
    where("name % ?", query)
      .order(Arel.sql("similarity(name, #{connection.quote(query)}) DESC"))
  }

  # Resolved cover art URL - prefers cached version, falls back to external
  def resolved_cover_art_url
    # Use cached image if available
    if cached_cover_art.attached?
      return cached_cover_art_url
    end

    # Queue caching if we have an external URL from a cacheable source
    if cover_art_url.present?
      source = cover_art_source.presence || ImageCachingService.detect_source(cover_art_url)
      if ImageCachingService.cacheable_source?(source)
        ImageCachingService.cache_image(
          record: self,
          attribute: :cover_art,
          url: cover_art_url,
          source: source
        )
      end
    end

    # Return external URL for now
    cover_art_url
  end

  def cached_cover_art_url
    return nil unless cached_cover_art.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      cached_cover_art,
      **active_storage_url_options
    )
  end

  private

  def detect_cover_art_source
    return if cover_art_url.blank?
    return if cover_art_source.present? # Don't override if explicitly set

    self.cover_art_source = ImageCachingService.detect_source(cover_art_url)
  end

  def queue_cover_art_caching
    return if cover_art_url.blank?
    return if cached_cover_art.attached?
    return unless ImageCachingService.cacheable_source?(cover_art_source)

    CacheExternalImageJob.perform_later(
      record_type: 'Album',
      record_id: id,
      attribute: 'cover_art',
      url: cover_art_url,
      source: cover_art_source
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
end
