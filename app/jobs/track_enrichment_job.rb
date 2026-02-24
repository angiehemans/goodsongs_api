# frozen_string_literal: true

class TrackEnrichmentJob < ApplicationJob
  queue_as :default

  # Retry on network errors with exponential backoff
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # Discard if the track no longer exists
  discard_on ActiveRecord::RecordNotFound

  def perform(track_id)
    track = Track.find(track_id)

    # Skip if already has ISRC and MusicBrainz ID
    return if track.isrc.present? && track.musicbrainz_recording_id.present?

    Rails.logger.info("TrackEnrichmentJob: Enriching track #{track_id} '#{track.name}'")

    enrich_track(track)
  end

  private

  def enrich_track(track)
    artist_name = track.band&.name
    return unless artist_name.present?

    # If we already have a MusicBrainz ID, just fetch the ISRC
    if track.musicbrainz_recording_id.present?
      fetch_and_update_isrc(track)
      return
    end

    # Search MusicBrainz for the recording
    recording = MusicbrainzService.find_recording(track.name, artist_name)
    return unless recording

    Rails.logger.info("TrackEnrichmentJob: Found MusicBrainz match for '#{track.name}' - MBID: #{recording[:mbid]}")

    updates = {}
    updates[:musicbrainz_recording_id] = recording[:mbid] if recording[:mbid].present?
    updates[:isrc] = recording[:isrcs]&.first if recording[:isrcs].present?
    updates[:duration_ms] = recording[:length] if track.duration_ms.blank? && recording[:length].present?

    if updates.any?
      track.update!(updates)
      Rails.logger.info("TrackEnrichmentJob: Updated track #{track.id} with: #{updates.keys.join(', ')}")

      # Queue streaming links enrichment if we now have an ISRC
      if updates[:isrc].present? && track.streaming_links_fetched_at.nil?
        StreamingLinksEnrichmentJob.perform_later(track.id)
        Rails.logger.info("TrackEnrichmentJob: Queued StreamingLinksEnrichmentJob for track #{track.id}")
      end
    end
  rescue StandardError => e
    Rails.logger.error("TrackEnrichmentJob: Error enriching track #{track.id}: #{e.message}")
    raise # Let the retry mechanism handle it
  end

  def fetch_and_update_isrc(track)
    return if track.isrc.present?

    recording = MusicbrainzService.get_recording(track.musicbrainz_recording_id)
    return unless recording

    isrc = recording[:isrcs]&.first
    if isrc.present?
      track.update!(isrc: isrc)
      Rails.logger.info("TrackEnrichmentJob: Updated track #{track.id} with ISRC: #{isrc}")

      # Queue streaming links enrichment now that we have ISRC
      if track.streaming_links_fetched_at.nil?
        StreamingLinksEnrichmentJob.perform_later(track.id)
        Rails.logger.info("TrackEnrichmentJob: Queued StreamingLinksEnrichmentJob for track #{track.id}")
      end
    end
  end
end
