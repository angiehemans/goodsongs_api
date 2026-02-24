# frozen_string_literal: true

class StreamingLinksEnrichmentJob < ApplicationJob
  queue_as :odesli

  # Retry on network errors with polynomial backoff
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError,
           wait: :polynomially_longer, attempts: 5

  # Discard if the track no longer exists
  discard_on ActiveRecord::RecordNotFound

  def perform(track_id)
    track = Track.find(track_id)

    # Skip if no ISRC (nothing to look up)
    if track.isrc.blank?
      Rails.logger.info("StreamingLinksEnrichmentJob: Skipping track #{track_id} - no ISRC")
      return
    end

    # Skip if already fetched
    if track.streaming_links_fetched_at.present?
      Rails.logger.info("StreamingLinksEnrichmentJob: Skipping track #{track_id} - already fetched")
      return
    end

    Rails.logger.info("StreamingLinksEnrichmentJob: Enriching track #{track_id} '#{track.name}' with ISRC #{track.isrc}")

    enrich_streaming_links(track)
  end

  private

  def enrich_streaming_links(track)
    # Use cached lookup if available
    result = ScrobbleCacheService.get_odesli_links_by_isrc(track.isrc)

    updates = { streaming_links_fetched_at: Time.current }

    if result
      updates[:streaming_links] = result[:links] if result[:links].present?
      updates[:songlink_url] = result[:page_url] if result[:page_url].present?

      Rails.logger.info("StreamingLinksEnrichmentJob: Found #{result[:links]&.keys&.length || 0} streaming links for track #{track.id}")
    else
      Rails.logger.info("StreamingLinksEnrichmentJob: No streaming links found for track #{track.id} (ISRC: #{track.isrc})")
    end

    track.update!(updates)
  rescue StandardError => e
    Rails.logger.error("StreamingLinksEnrichmentJob: Error enriching track #{track.id}: #{e.message}")
    raise
  end
end
