# frozen_string_literal: true

class MusicbrainzSyncJob < ApplicationJob
  queue_as :default

  # Stub for future weekly incremental sync.
  #
  # MusicBrainz publishes replication packets (dbmirror_pending / dbmirror_pendingdata)
  # that can be applied incrementally. Parsing this format requires substantial work
  # and is deferred to a future phase.
  #
  # In the meantime, a full re-import via `rake musicbrainz:full_import` can serve
  # as a periodic refresh.
  def perform
    Rails.logger.info "[MB Sync] MusicBrainz incremental sync is not yet implemented."
    Rails.logger.info "[MB Sync] Use `rake musicbrainz:full_import` for a full refresh."
  end
end
