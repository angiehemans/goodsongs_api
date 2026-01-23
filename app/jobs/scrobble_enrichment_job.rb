# frozen_string_literal: true

class ScrobbleEnrichmentJob < ApplicationJob
  queue_as :default

  # Retry on network errors with exponential backoff
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # Discard if the scrobble no longer exists
  discard_on ActiveRecord::RecordNotFound

  def perform(scrobble_id)
    scrobble = Scrobble.find(scrobble_id)

    # Skip if already processed
    return unless scrobble.pending?

    Rails.logger.info("ScrobbleEnrichmentJob: Enriching scrobble #{scrobble_id}")

    result = ScrobbleEnrichmentService.enrich(scrobble)

    if result
      Rails.logger.info("ScrobbleEnrichmentJob: Successfully enriched scrobble #{scrobble_id}")
    else
      Rails.logger.info("ScrobbleEnrichmentJob: Could not enrich scrobble #{scrobble_id}, status: #{scrobble.reload.metadata_status}")
    end
  end
end
