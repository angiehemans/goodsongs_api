# frozen_string_literal: true

class ScrobbleEnrichmentService
  attr_reader :scrobble

  # Mapping of MusicBrainz release types to normalized types
  RELEASE_TYPE_MAP = {
    'Album' => 'album',
    'Single' => 'single',
    'EP' => 'ep',
    'Compilation' => 'compilation',
    'Live' => 'live',
    'Remix' => 'remix',
    'Soundtrack' => 'soundtrack'
  }.freeze

  def initialize(scrobble)
    @scrobble = scrobble
  end

  # Main enrichment method - returns true if successful
  def enrich!
    return false unless scrobble.pending?

    # Try MusicBrainz first
    recording = find_recording
    if recording
      return enrich_from_musicbrainz!(recording)
    end

    # Fallback to Discogs
    Rails.logger.info("MusicBrainz not found for '#{scrobble.track_name}' by '#{scrobble.artist_name}', trying Discogs...")
    discogs_result = find_discogs_recording
    if discogs_result
      return enrich_from_discogs!(discogs_result)
    end

    # Neither source found the track
    scrobble.update!(metadata_status: :not_found)
    false
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

  # ============================================
  # MusicBrainz Enrichment
  # ============================================

  def enrich_from_musicbrainz!(recording)
    band = find_or_create_band(recording)
    album = find_or_create_album(recording, band)
    track = find_or_create_track(recording, band, album)

    scrobble.update!(
      track: track,
      musicbrainz_recording_id: recording[:mbid],
      metadata_status: :enriched
    )

    true
  end

  def find_or_create_band(recording)
    artist_data = recording[:artists]&.first
    return nil unless artist_data

    mbid = artist_data[:mbid]
    name = artist_data[:name]

    # 1. Exact MBID match
    if mbid.present?
      band = Band.find_by(musicbrainz_id: mbid)
      if band
        # Backfill additional fields if missing
        backfill_band_from_musicbrainz(band, mbid)
        return band
      end
    end

    # 2. Case-insensitive name match, backfill MBID
    if name.present?
      band = Band.where("LOWER(name) = LOWER(?)", name).first
      if band
        if mbid.present? && band.musicbrainz_id.blank?
          band.update!(musicbrainz_id: mbid)
          backfill_band_from_musicbrainz(band, mbid)
        end
        return band
      end
    end

    # 3. Create new band — fetch full artist details from MusicBrainz
    full_artist = mbid.present? ? MusicbrainzService.get_artist(mbid) : nil
    image_url = fetch_artist_image(full_artist)

    Band.create!(
      name: name,
      musicbrainz_id: mbid,
      artist_image_url: image_url,
      about: extract_artist_bio(full_artist),
      sort_name: full_artist&.dig(:sort_name),
      artist_type: full_artist&.dig(:type),
      country: full_artist&.dig(:country),
      genres: full_artist&.dig(:genres)&.first(5) || [],
      spotify_link: extract_streaming_url(full_artist, 'spotify'),
      apple_music_link: extract_streaming_url(full_artist, 'apple_music'),
      bandcamp_link: extract_streaming_url(full_artist, 'bandcamp'),
      youtube_music_link: extract_streaming_url(full_artist, 'youtube')
    )
  end

  def backfill_band_from_musicbrainz(band, mbid)
    # Only backfill if key fields are missing
    return if band.genres.present? && band.country.present? && band.artist_type.present?

    full_artist = MusicbrainzService.get_artist(mbid)
    return unless full_artist

    updates = {}
    updates[:sort_name] = full_artist[:sort_name] if band.sort_name.blank? && full_artist[:sort_name].present?
    updates[:artist_type] = full_artist[:type] if band.artist_type.blank? && full_artist[:type].present?
    updates[:country] = full_artist[:country] if band.country.blank? && full_artist[:country].present?
    updates[:genres] = full_artist[:genres]&.first(5) if band.genres.blank? && full_artist[:genres].present?
    updates[:spotify_link] = extract_streaming_url(full_artist, 'spotify') if band.spotify_link.blank?
    updates[:apple_music_link] = extract_streaming_url(full_artist, 'apple_music') if band.apple_music_link.blank?
    updates[:bandcamp_link] = extract_streaming_url(full_artist, 'bandcamp') if band.bandcamp_link.blank?
    updates[:youtube_music_link] = extract_streaming_url(full_artist, 'youtube') if band.youtube_music_link.blank?

    band.update!(updates) if updates.any?
  rescue StandardError => e
    Rails.logger.warn("Failed to backfill band #{band.id}: #{e.message}")
  end

  def extract_streaming_url(artist_data, service)
    return nil unless artist_data&.dig(:urls)

    urls = artist_data[:urls]
    case service
    when 'spotify'
      urls['spotify'] || urls['free_streaming']&.include?('spotify') && urls['free_streaming']
    when 'apple_music'
      urls['apple_music']
    when 'bandcamp'
      urls['bandcamp']
    when 'youtube'
      urls['youtube']
    end
  end

  def find_or_create_album(recording, band)
    release = select_best_release(recording[:releases])
    return nil unless release && release[:mbid]

    album = Album.find_by(musicbrainz_release_id: release[:mbid])
    if album
      # Backfill additional fields if missing
      backfill_album_fields(album, release, band)
      # Backfill cover art if missing using Discogs fallback
      if album.cover_art_url.blank?
        cover_art_url = fetch_cover_art_with_fallback(release[:mbid], release[:title], band&.name)
        album.update!(cover_art_url: cover_art_url) if cover_art_url.present?
      end
      return album
    end

    # Fetch cover art with Discogs fallback
    cover_art_url = fetch_cover_art_with_fallback(release[:mbid], release[:title], band&.name)

    Album.create!(
      name: release[:title],
      band: band,
      musicbrainz_release_id: release[:mbid],
      cover_art_url: cover_art_url,
      release_date: parse_release_date(release[:date]),
      release_type: normalize_release_type(release[:release_type], release[:secondary_types]),
      country: release[:country],
      genres: band&.genres || []
    )
  end

  def backfill_album_fields(album, release, band)
    updates = {}
    updates[:release_type] = normalize_release_type(release[:release_type], release[:secondary_types]) if album.release_type.blank?
    updates[:country] = release[:country] if album.country.blank? && release[:country].present?
    updates[:genres] = band&.genres if album.genres.blank? && band&.genres.present?

    album.update!(updates) if updates.any?
  rescue StandardError => e
    Rails.logger.warn("Failed to backfill album #{album.id}: #{e.message}")
  end

  def normalize_release_type(primary_type, secondary_types = [])
    return nil if primary_type.blank?

    # Check secondary types first for more specific categorization
    secondary_types = Array(secondary_types)
    if secondary_types.include?('Compilation')
      return 'compilation'
    elsif secondary_types.include?('Live')
      return 'live'
    elsif secondary_types.include?('Remix')
      return 'remix'
    elsif secondary_types.include?('Soundtrack')
      return 'soundtrack'
    end

    # Map primary type
    RELEASE_TYPE_MAP[primary_type] || 'other'
  end

  def find_or_create_track(recording, band, album)
    track = Track.find_by(musicbrainz_recording_id: recording[:mbid])
    if track
      # Backfill genres if missing
      if track.genres.blank? && (album&.genres.present? || band&.genres.present?)
        track.update(genres: album&.genres.presence || band&.genres || [])
      end
      return track
    end

    Track.create!(
      name: recording[:title],
      band: band,
      album: album,
      duration_ms: recording[:length],
      musicbrainz_recording_id: recording[:mbid],
      isrc: recording[:isrcs]&.first,
      genres: album&.genres.presence || band&.genres || []
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

  # Fetch cover art with multiple fallbacks when Cover Art Archive doesn't have it
  def fetch_cover_art_with_fallback(release_mbid, album_name, artist_name)
    # Try Cover Art Archive first
    cover_art_url = fetch_cover_art(release_mbid)
    return cover_art_url if cover_art_url.present?

    # Fallback to TheAudioDB
    Rails.logger.info("Cover Art Archive not found for '#{album_name}' by '#{artist_name}', trying TheAudioDB...")
    cover_art_url = fetch_cover_art_from_audiodb(album_name, artist_name)
    return cover_art_url if cover_art_url.present?

    # Fallback to Discogs for cover art
    Rails.logger.info("TheAudioDB not found for '#{album_name}' by '#{artist_name}', trying Discogs...")
    fetch_cover_art_from_discogs(album_name, artist_name)
  end

  def fetch_cover_art_from_audiodb(album_name, artist_name)
    return nil if album_name.blank? || artist_name.blank?

    album = ScrobbleCacheService.get_audiodb_album(artist_name, album_name)
    return nil unless album

    # Prefer HQ thumb, then regular thumb
    cover_art = album[:album_thumb_hq].presence || album[:album_thumb].presence
    if cover_art.present?
      Rails.logger.info("TheAudioDB cover art found for '#{album_name}' by '#{artist_name}'")
    end
    cover_art
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch TheAudioDB cover art for '#{album_name}': #{e.message}")
    nil
  end

  def fetch_cover_art_from_discogs(album_name, artist_name)
    return nil if album_name.blank? || artist_name.blank?

    cover_art = ScrobbleCacheService.get_discogs_cover_art(album_name, artist_name)
    if cover_art.present?
      Rails.logger.info("Discogs cover art found for '#{album_name}' by '#{artist_name}'")
    end
    cover_art
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch Discogs cover art for '#{album_name}': #{e.message}")
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

  # ============================================
  # Discogs Fallback Enrichment
  # ============================================

  def find_discogs_recording
    # Search Discogs for the track + artist
    results = ScrobbleCacheService.get_discogs_search(scrobble.track_name, scrobble.artist_name)
    return nil if results.blank?

    # Find a result that contains a matching track in the tracklist
    results.each do |result|
      master_id = result[:master_id] || result[:id]
      next unless master_id

      # Get master details to check tracklist
      master = ScrobbleCacheService.get_discogs_master(master_id)
      next unless master

      # Check if the track exists in the tracklist
      matching_track = find_matching_track_in_discogs(master[:tracklist])
      if matching_track
        Rails.logger.info("Discogs match found: '#{master[:title]}' by '#{master[:artist]}'")
        return { master: master, track: matching_track }
      end
    end

    nil
  end

  def find_matching_track_in_discogs(tracklist)
    return nil if tracklist.blank?

    normalized_search = normalize_track_name(scrobble.track_name)

    tracklist.find do |track|
      normalized_title = normalize_track_name(track[:title])
      normalized_title == normalized_search || normalized_title.include?(normalized_search) || normalized_search.include?(normalized_title)
    end
  end

  def normalize_track_name(name)
    return '' if name.blank?
    name.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, ' ').strip
  end

  def enrich_from_discogs!(discogs_result)
    master = discogs_result[:master]
    track_data = discogs_result[:track]

    band = find_or_create_band_from_discogs(master)
    album = find_or_create_album_from_discogs(master, band)
    track = find_or_create_track_from_discogs(track_data, band, album, master)

    scrobble.update!(
      track: track,
      metadata_status: :enriched
    )

    Rails.logger.info("Successfully enriched scrobble #{scrobble.id} from Discogs")
    true
  end

  def find_or_create_band_from_discogs(master)
    artist_name = master[:artist]
    artist_id = master[:artist_id]&.to_s

    # 1. Check by Discogs artist ID
    if artist_id.present?
      band = Band.find_by(discogs_artist_id: artist_id)
      return band if band
    end

    # 2. Case-insensitive name match, backfill Discogs ID
    if artist_name.present?
      band = Band.where("LOWER(name) = LOWER(?)", artist_name).first
      if band
        if artist_id.present? && band.discogs_artist_id.blank?
          band.update!(discogs_artist_id: artist_id)
        end
        # Backfill genres if missing
        if band.genres.blank? && master[:genres].present?
          band.update!(genres: master[:genres].first(5))
        end
        return band
      end
    end

    # 3. Create new band from Discogs data
    Band.create!(
      name: artist_name,
      discogs_artist_id: artist_id,
      genres: master[:genres]&.first(5) || [],
      source: :musicbrainz  # Keep source as default, use discogs_artist_id to identify source
    )
  end

  def find_or_create_album_from_discogs(master, band)
    master_id = master[:id]&.to_s
    return nil unless master_id

    # 1. Check by Discogs master ID
    album = Album.find_by(discogs_master_id: master_id)
    return album if album

    # 2. Create new album from Discogs data
    Album.create!(
      name: master[:title],
      band: band,
      discogs_master_id: master_id,
      cover_art_url: master[:cover_image],
      release_date: master[:year].present? ? Date.new(master[:year].to_i, 1, 1) : nil,
      genres: master[:genres]&.first(5) || band&.genres || [],
      release_type: 'album'  # Discogs masters are typically albums
    )
  end

  def find_or_create_track_from_discogs(track_data, band, album, master)
    # Create a composite ID for the track (master_id + position)
    discogs_track_id = "#{master[:id]}-#{track_data[:position]}"

    # 1. Check by Discogs track ID
    track = Track.find_by(discogs_track_id: discogs_track_id)
    return track if track

    # 2. Create new track from Discogs data
    Track.create!(
      name: track_data[:title],
      band: band,
      album: album,
      discogs_track_id: discogs_track_id,
      duration_ms: parse_discogs_duration(track_data[:duration]),
      track_number: parse_track_position(track_data[:position]),
      genres: album&.genres.presence || band&.genres || []
    )
  end

  def parse_discogs_duration(duration_string)
    return nil if duration_string.blank?

    # Discogs duration is in format "M:SS" or "MM:SS"
    parts = duration_string.split(':')
    return nil unless parts.length == 2

    minutes = parts[0].to_i
    seconds = parts[1].to_i
    (minutes * 60 + seconds) * 1000  # Convert to milliseconds
  rescue StandardError
    nil
  end

  def parse_track_position(position)
    return nil if position.blank?

    # Position can be "1", "A1", "B2", etc.
    # Extract the numeric part
    match = position.match(/(\d+)$/)
    match ? match[1].to_i : nil
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
