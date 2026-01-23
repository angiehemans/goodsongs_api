# frozen_string_literal: true

class ScrobbleEnrichmentService
  attr_reader :scrobble

  def initialize(scrobble)
    @scrobble = scrobble
  end

  # Main enrichment method - returns true if successful
  def enrich!
    return false unless scrobble.pending?

    recording = find_recording
    unless recording
      scrobble.update!(metadata_status: :not_found)
      return false
    end

    # Get or create canonical records
    artist = find_or_create_artist(recording)
    album = find_or_create_album(recording, artist)
    track = find_or_create_track(recording, artist, album)

    # Update scrobble with enriched data
    scrobble.update!(
      track: track,
      musicbrainz_recording_id: recording[:mbid],
      metadata_status: :enriched
    )

    true
  rescue StandardError => e
    Rails.logger.error("ScrobbleEnrichmentService error for scrobble #{scrobble.id}: #{e.message}")
    scrobble.update!(metadata_status: :failed)
    false
  end

  private

  def find_recording
    # Use cached MusicBrainz lookup (24 hour TTL)
    ScrobbleCacheService.get_musicbrainz_recording(scrobble.track_name, scrobble.artist_name)
  end

  def find_or_create_artist(recording)
    artist_data = recording[:artists]&.first
    return nil unless artist_data && artist_data[:mbid]

    artist = Artist.find_by(musicbrainz_artist_id: artist_data[:mbid])
    return artist if artist

    # Fetch full artist details from MusicBrainz
    full_artist = MusicbrainzService.get_artist(artist_data[:mbid])

    # Try to get artist image from existing sources
    image_url = fetch_artist_image(full_artist)

    Artist.create!(
      name: artist_data[:name],
      musicbrainz_artist_id: artist_data[:mbid],
      image_url: image_url,
      bio: extract_artist_bio(full_artist)
    )
  end

  def find_or_create_album(recording, artist)
    release = select_best_release(recording[:releases])
    return nil unless release && release[:mbid]

    album = Album.find_by(musicbrainz_release_id: release[:mbid])
    return album if album

    # Fetch cover art
    cover_art_url = fetch_cover_art(release[:mbid])

    Album.create!(
      name: release[:title],
      artist: artist,
      musicbrainz_release_id: release[:mbid],
      cover_art_url: cover_art_url,
      release_date: parse_release_date(release[:date])
    )
  end

  def find_or_create_track(recording, artist, album)
    track = Track.find_by(musicbrainz_recording_id: recording[:mbid])
    return track if track

    Track.create!(
      name: recording[:title],
      artist: artist,
      album: album,
      duration_ms: recording[:length],
      musicbrainz_recording_id: recording[:mbid],
      isrc: recording[:isrcs]&.first
    )
  end

  # Select the best release (album) from available releases
  # Prefer: official releases, albums over singles, earlier releases
  def select_best_release(releases)
    return nil if releases.blank?

    # Sort by preference
    releases.sort_by do |release|
      [
        release[:status] == 'Official' ? 0 : 1,  # Official first
        release[:date].present? ? 0 : 1,          # Has date
        release[:date].to_s                        # Earlier date
      ]
    end.first
  end

  def fetch_cover_art(release_mbid)
    # Use cached Cover Art lookup (24 hour TTL)
    ScrobbleCacheService.get_cover_art_url(release_mbid, size: 500)
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch cover art for #{release_mbid}: #{e.message}")
    nil
  end

  def fetch_artist_image(artist_data)
    return nil unless artist_data

    # Try Fanart.tv if available
    if artist_data[:mbid] && defined?(FanartTvService)
      image = FanartTvService.get_artist_thumb(artist_data[:mbid])
      return image if image.present?
    end

    # Could add Wikipedia/Wikidata image fetching here
    # For now, leave nil and let it be populated later
    nil
  rescue StandardError
    nil
  end

  def extract_artist_bio(artist_data)
    return nil unless artist_data

    # Build a simple bio from available data
    parts = []
    parts << artist_data[:type] if artist_data[:type].present?

    location = [artist_data[:begin_area], artist_data[:country]].compact.join(', ')
    parts << "from #{location}" if location.present?

    genres = artist_data[:genres] || artist_data[:tags]&.first(3)
    parts << genres.join(', ') if genres.present?

    parts.any? ? parts.join(' · ') : nil
  end

  def parse_release_date(date_string)
    return nil if date_string.blank?

    # MusicBrainz dates can be YYYY, YYYY-MM, or YYYY-MM-DD
    case date_string.length
    when 4
      Date.new(date_string.to_i, 1, 1)
    when 7
      Date.strptime(date_string, '%Y-%m')
    when 10
      Date.strptime(date_string, '%Y-%m-%d')
    else
      nil
    end
  rescue ArgumentError
    nil
  end

  class << self
    # Enrich a single scrobble
    def enrich(scrobble)
      new(scrobble).enrich!
    end

    # Batch enrich multiple scrobbles
    def enrich_batch(scrobbles)
      results = { success: 0, not_found: 0, failed: 0 }

      scrobbles.each do |scrobble|
        result = enrich(scrobble)
        if result
          results[:success] += 1
        elsif scrobble.reload.not_found?
          results[:not_found] += 1
        else
          results[:failed] += 1
        end
      end

      results
    end
  end
end
