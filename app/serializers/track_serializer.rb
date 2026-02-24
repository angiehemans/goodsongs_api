# frozen_string_literal: true

class TrackSerializer
  class << self
    # Basic track info without streaming links
    def summary(track)
      {
        id: track.id,
        name: track.name,
        album: track.album ? { id: track.album.id, name: track.album.name } : nil,
        band: track.band ? { id: track.band.id, name: track.band.name } : nil,
        source: track.source,
        duration_ms: track.duration_ms
      }
    end

    # Full track with all details including streaming links
    def full(track)
      {
        id: track.id,
        name: track.name,
        album: track.album ? { id: track.album.id, name: track.album.name } : nil,
        band: track.band ? { id: track.band.id, name: track.band.name } : nil,
        source: track.source,
        duration_ms: track.duration_ms,
        isrc: track.isrc,
        musicbrainz_recording_id: track.musicbrainz_recording_id,
        track_number: track.track_number,
        genres: track.genres || [],
        streaming_links: track.streaming_links || {},
        songlink_url: track.songlink_url,
        created_at: track.created_at,
        updated_at: track.updated_at
      }
    end

    # Summary with streaming links (for review context)
    def with_links(track)
      {
        id: track.id,
        name: track.name,
        album: track.album ? { id: track.album.id, name: track.album.name } : nil,
        band: track.band ? { id: track.band.id, name: track.band.name } : nil,
        source: track.source,
        streaming_links: track.streaming_links || {},
        songlink_url: track.songlink_url,
        songlink_search_url: track.songlink_search_url
      }
    end
  end
end
