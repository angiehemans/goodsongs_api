# frozen_string_literal: true

# Fast song search service that prioritizes local database,
# then falls back to external APIs (TheAudioDB, Discogs)
class SongSearchService
  DEFAULT_LIMIT = 10
  MIN_LOCAL_RESULTS = 3  # Minimum local results before trying external APIs

  def initialize(track:, artist: nil, limit: DEFAULT_LIMIT)
    @track = track&.strip.presence
    @artist = artist&.strip.presence
    @limit = limit
  end

  def search
    return [] if @track.blank?

    results = []

    # 1. If artist is provided, search TheAudioDB first (requires artist, but has great results)
    if @artist.present?
      audiodb_results = search_audiodb
      results.concat(audiodb_results)

      # If we have enough results from AudioDB, return them
      return results.first(@limit) if results.length >= @limit
    end

    # 2. Search local database (works without artist, instant)
    local_results = search_local_database
    results.concat(local_results)
    results = dedupe_results(results)

    return results.first(@limit) if results.length >= @limit

    # 3. Fall back to Discogs if still not enough (slowest)
    if results.length < MIN_LOCAL_RESULTS
      discogs_results = search_discogs
      results.concat(discogs_results)
      results = dedupe_results(results)
    end

    results.first(@limit)
  end

  private

  def search_local_database
    tracks = Track.includes(:band, :album)

    query_words = @track.downcase.split.reject { |w| w.length < 2 }

    if query_words.length > 1
      # Multi-word query: require all words to be present in the track name
      # This prevents "Dark Green Water" from matching just "Water"
      conditions = query_words.map { |word| "LOWER(tracks.name) LIKE #{Track.connection.quote("%#{word}%")}" }
      tracks = tracks.where(conditions.join(' AND '))
    else
      # Single word query: use trigram similarity OR prefix match
      tracks = tracks.where("name % ? OR LOWER(name) LIKE ?", @track, "#{@track.downcase}%")
    end

    # Filter by artist if provided
    if @artist.present?
      tracks = tracks.joins(:band).where("bands.name % ?", @artist)
    end

    # Order by: exact matches first, then prefix matches, then by similarity
    tracks = tracks.order(
      Arel.sql("CASE WHEN LOWER(tracks.name) = #{Track.connection.quote(@track.downcase)} THEN 0 ELSE 1 END"),
      Arel.sql("CASE WHEN LOWER(tracks.name) LIKE #{Track.connection.quote("#{@track.downcase}%")} THEN 0 ELSE 1 END"),
      Arel.sql("similarity(tracks.name, #{Track.connection.quote(@track)}) DESC")
    )
    tracks = tracks.limit(@limit * 2)

    tracks.map { |track| format_local_track(track) }
  rescue StandardError => e
    Rails.logger.warn("SongSearchService local search error: #{e.message}")
    []
  end

  def search_audiodb
    # Search AudioDB for multiple track matches
    tracks = AudioDbService.search_tracks(artist: @artist, track: @track, limit: @limit)
    return [] if tracks.blank?

    tracks.map { |track_data| format_audiodb_track(track_data) }
  rescue StandardError => e
    Rails.logger.warn("SongSearchService AudioDB error: #{e.message}")
    []
  end

  def search_discogs
    # Use cached Discogs search - this returns albums, not tracks
    results = DiscogsService.search(track: @track, artist: @artist, limit: 5)
    return [] if results.blank?

    # For each Discogs result, try to get the actual track name from AudioDB
    # using the artist name we found
    enhanced_results = []

    results.first(5).each do |release|
      break if enhanced_results.length >= 3

      artist_name = release[:artist]
      next if artist_name.blank?

      # Try AudioDB to get the real track name
      audiodb_tracks = AudioDbService.search_tracks(artist: artist_name, track: @track, limit: 1)

      if audiodb_tracks.any?
        # Found the real track in AudioDB
        enhanced_results << format_audiodb_track(audiodb_tracks.first).merge(
          album_title: release[:title],
          artwork_url: audiodb_tracks.first[:track_thumb].presence || release[:cover_image],
          release_year: release[:year]
        )
      else
        # Couldn't find in AudioDB, mark as album result
        enhanced_results << format_discogs_result(release)
      end
    end

    enhanced_results
  rescue StandardError => e
    Rails.logger.warn("SongSearchService Discogs error: #{e.message}")
    []
  end

  def format_local_track(track)
    {
      song_name: track.name,
      band_name: track.band&.name,
      album_title: track.album&.name,
      release_year: track.album&.release_date&.year,
      artwork_url: track.album&.cover_art_url,
      duration: format_duration(track.duration_ms),
      source: 'local',
      track_id: track.id,
      band_id: track.band_id,
      album_id: track.album_id,
      musicbrainz_id: track.musicbrainz_recording_id
    }
  end

  def format_audiodb_track(track_data)
    {
      song_name: track_data[:name],
      band_name: track_data[:artist_name],
      album_title: track_data[:album_name],
      release_year: nil,  # AudioDB track search doesn't return year
      artwork_url: track_data[:track_thumb],
      duration: format_duration(track_data[:duration_ms]),
      source: 'audiodb',
      audiodb_track_id: track_data[:id],
      musicbrainz_id: track_data[:musicbrainz_id]
    }
  end

  def format_discogs_result(release)
    {
      song_name: @track,  # Discogs returns albums, use search query
      band_name: release[:artist],
      album_title: release[:title],
      release_year: release[:year],
      artwork_url: release[:cover_image],
      source: 'discogs',
      master_id: release[:master_id],
      discogs_url: "https://www.discogs.com/master/#{release[:master_id]}",
      is_album_result: true  # Flag that this is an album, not a track
    }
  end

  def format_duration(ms)
    return nil unless ms.present? && ms > 0

    total_seconds = ms / 1000
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end

  def dedupe_results(results)
    seen = Set.new
    results.select do |r|
      # Create a normalized key for deduplication
      key = normalize_for_dedupe(r[:song_name], r[:band_name])
      if seen.include?(key)
        false
      else
        seen.add(key)
        true
      end
    end
  end

  def normalize_for_dedupe(song, artist)
    song_norm = song.to_s.downcase.gsub(/[^a-z0-9]/, '')
    artist_norm = artist.to_s.downcase.gsub(/[^a-z0-9]/, '')
    "#{song_norm}:#{artist_norm}"
  end

  class << self
    def search(track:, artist: nil, limit: DEFAULT_LIMIT)
      new(track: track, artist: artist, limit: limit).search
    end
  end
end
