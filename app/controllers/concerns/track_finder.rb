# frozen_string_literal: true

# Shared track/band lookup logic for reviews and posts
module TrackFinder
  extend ActiveSupport::Concern

  private

  def find_or_create_track(band, song_name)
    return nil if band.blank? || song_name.blank?

    song = song_name.strip

    # 1. Exact case-insensitive match on band's tracks
    track = band.tracks.where("LOWER(name) = LOWER(?)", song).first
    if track
      queue_streaming_links_if_needed(track)
      return track
    end

    # 2. Fuzzy match with >0.6 similarity threshold
    similar_track = band.tracks
      .where("name % ?", song)
      .where("similarity(name, ?) > 0.6", song)
      .order(Arel.sql("similarity(name, #{Track.connection.quote(song)}) DESC"))
      .first
    if similar_track
      queue_streaming_links_if_needed(similar_track)
      return similar_track
    end

    # 3. Create new user-submitted track
    track = Track.create!(
      name: song,
      band: band,
      source: :user_submitted,
      submitted_by: current_user
    )

    # Queue background job to enrich track with MusicBrainz data (ISRC, etc.)
    begin
      TrackEnrichmentJob.perform_later(track.id)
    rescue StandardError => e
      Rails.logger.warn("Failed to queue track enrichment for track #{track.id}: #{e.message}")
    end

    track
  end

  def queue_streaming_links_if_needed(track)
    return unless track.isrc.present? && track.streaming_links_fetched_at.nil?
    StreamingLinksEnrichmentJob.perform_later(track.id)
  rescue StandardError => e
    Rails.logger.warn("Failed to queue streaming links for track #{track.id}: #{e.message}")
  end

  def find_or_create_band(band_name)
    return nil if band_name.blank?

    name = band_name.strip
    mbid = band_musicbrainz_id

    # 1. Exact MBID match (most reliable identifier)
    if mbid.present?
      band = Band.find_by(musicbrainz_id: mbid)
      return backfill_band(band) if band
    end

    # 2. Case-insensitive exact name match
    band = Band.where("LOWER(name) = LOWER(?)", name).first
    return backfill_band(band) if band

    # 3. Handle "The" prefix variations - "The Beatles" <-> "Beatles"
    normalized = name.sub(/\Athe\s+/i, '')
    with_the = "The #{normalized}"
    band = Band.where("LOWER(name) = LOWER(?) OR LOWER(name) = LOWER(?)", normalized, with_the).first
    return backfill_band(band) if band

    # 4. Check band aliases
    band_alias = BandAlias.where("LOWER(name) = LOWER(?)", name).first
    return backfill_band(band_alias.band) if band_alias

    # 5. Create new band
    band = Band.new(name: name)
    backfill_band(band, new_band: true)
  end

  def backfill_band(band, new_band: false)
    if band_lastfm_artist_name.present? && band.lastfm_artist_name.blank?
      band.lastfm_artist_name = band_lastfm_artist_name
    end

    if band_musicbrainz_id.present? && band.musicbrainz_id.blank?
      band.musicbrainz_id = band_musicbrainz_id
    end

    band.save! if band.new_record? || band.changed?

    # Queue enrichment for new bands or existing bands missing streaming links
    queue_band_enrichment_if_needed(band, new_band: new_band)

    band
  end

  def queue_band_enrichment_if_needed(band, new_band: false)
    # Always enrich new bands
    # For existing bands, only enrich if missing streaming links
    needs_enrichment = new_band || (band.spotify_link.blank? && band.apple_music_link.blank?)
    return unless needs_enrichment

    BandEnrichmentJob.perform_later(band.id)
  rescue StandardError => e
    Rails.logger.warn("Failed to queue band enrichment for band #{band.id}: #{e.message}")
  end

  # Override these in controllers that need different param sources
  def band_lastfm_artist_name
    nil
  end

  def band_musicbrainz_id
    nil
  end
end
