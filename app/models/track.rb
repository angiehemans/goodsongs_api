# frozen_string_literal: true

# Canonical track data from MusicBrainz
class Track < ApplicationRecord
  include ImageUrlHelper

  belongs_to :band, optional: true
  belongs_to :album, optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  has_many :scrobbles, dependent: :nullify
  has_many :reviews, dependent: :nullify
  has_one_attached :artwork

  enum :source, { musicbrainz: 0, user_submitted: 1 }

  validates :name, presence: true
  validates :musicbrainz_recording_id, uniqueness: true, allow_nil: true

  scope :search_by_name, ->(query) {
    where("name % ?", query)
      .order(Arel.sql("similarity(name, #{connection.quote(query)}) DESC"))
  }

  # Tracks with ISRC that need initial streaming links fetch
  scope :needs_streaming_links, -> {
    where.not(isrc: nil).where(streaming_links_fetched_at: nil)
  }

  # Tracks with reviews that need streaming links (for backfill)
  scope :reviewed_needs_streaming_links, -> {
    joins(:reviews).needs_streaming_links.distinct
  }

  # Streaming link helper methods
  def spotify_url
    streaming_links&.dig('spotify')
  end

  def apple_music_url
    streaming_links&.dig('appleMusic')
  end

  def youtube_music_url
    streaming_links&.dig('youtubeMusic')
  end

  def tidal_url
    streaming_links&.dig('tidal')
  end

  def amazon_music_url
    streaming_links&.dig('amazonMusic')
  end

  def deezer_url
    streaming_links&.dig('deezer')
  end

  def soundcloud_url
    streaming_links&.dig('soundcloud')
  end

  def bandcamp_url
    streaming_links&.dig('bandcamp')
  end

  # Resolved artwork URL — prefers uploaded image, then external URL, then album artwork
  def resolved_artwork_url
    if artwork.attached?
      return Rails.application.routes.url_helpers.rails_blob_url(artwork, **active_storage_url_options)
    end

    return artwork_url if artwork_url.present?

    album&.resolved_cover_art_url
  end

  def has_streaming_links?
    streaming_links.present? && streaming_links.any?
  end

  # Fallback search URL when no direct streaming links available
  # Uses Google search to help users find the song on streaming platforms
  def songlink_search_url
    query = [band&.name, name].compact.join(' ')
    return nil if query.blank?
    "https://www.google.com/search?q=#{ERB::Util.url_encode(query + ' spotify OR apple music')}"
  end
end
