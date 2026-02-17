# frozen_string_literal: true

class ArtworkSearchController < ApplicationController
  include ResourceController

  skip_before_action :require_onboarding_completed
  before_action :check_search_rate_limit

  SEARCH_RATE_LIMIT_PER_MINUTE = 20

  # GET /artwork/search?track=...&artist=...&album=...
  # Returns artwork options from multiple sources for the user to choose from
  # Results are sorted with exact matches first, then other albums by the artist
  def search
    track = params[:track]&.strip.presence
    artist = params[:artist]&.strip.presence
    album = params[:album]&.strip.presence

    if track.blank? && artist.blank? && album.blank?
      render json: { error: 'Track, artist, or album name is required' }, status: :bad_request
      return
    end

    artwork_options = fetch_artwork_from_all_sources(track: track, artist: artist, album: album)

    # Group by match type for easier frontend handling
    exact_matches = artwork_options.select { |opt| opt[:match_type] == 'exact' }
    artist_catalog = artwork_options.select { |opt| opt[:match_type] == 'artist_catalog' }

    json_response({
      artwork_options: artwork_options,
      exact_matches: exact_matches,
      artist_catalog: artist_catalog,
      query: { track: track, artist: artist, album: album }
    })
  end

  private

  def fetch_artwork_from_all_sources(track:, artist:, album:)
    options = []

    # Fetch from all sources in parallel using threads
    threads = []

    # 1. Cover Art Archive (via MusicBrainz)
    threads << Thread.new do
      Thread.current[:result] = fetch_cover_art_archive(track: track, artist: artist, album: album)
    end

    # 2. Discogs
    threads << Thread.new do
      Thread.current[:result] = fetch_discogs_artwork(track: track, artist: artist, album: album)
    end

    # 3. Last.fm (artist images, can sometimes have album art)
    threads << Thread.new do
      Thread.current[:result] = fetch_lastfm_artwork(artist: artist, album: album)
    end

    # 4. TheAudioDB
    threads << Thread.new do
      Thread.current[:result] = fetch_audiodb_artwork(track: track, artist: artist, album: album)
    end

    # Wait for all threads and collect results
    threads.each(&:join)
    threads.each do |t|
      results = t[:result]
      options.concat(results) if results.present?
    end

    # Mark match types based on album name similarity
    options.each do |opt|
      opt[:match_type] = determine_match_type(opt[:album_name], album, track)
    end

    # Deduplicate by URL and sort by match type, then source priority
    deduplicate_and_sort_artwork(options)
  end

  def determine_match_type(result_album_name, query_album, query_track)
    return 'artist_catalog' if result_album_name.blank?

    result_normalized = normalize_for_comparison(result_album_name)

    # Check if it matches the requested album
    if query_album.present?
      query_normalized = normalize_for_comparison(query_album)
      return 'exact' if fuzzy_match?(result_normalized, query_normalized)
    end

    # Check if the album name contains the track name (likely a single or EP)
    if query_track.present?
      track_normalized = normalize_for_comparison(query_track)
      return 'exact' if fuzzy_match?(result_normalized, track_normalized)
    end

    'artist_catalog'
  end

  def normalize_for_comparison(str)
    str.to_s
       .downcase
       .gsub(/[^\w\s]/, '') # Remove punctuation
       .gsub(/\s+/, ' ')    # Normalize whitespace
       .strip
  end

  def fuzzy_match?(str1, str2)
    return true if str1 == str2
    return true if str1.include?(str2) || str2.include?(str1)

    # Check for high similarity (handles minor differences like "Deluxe Edition")
    return true if str1.start_with?(str2) || str2.start_with?(str1)

    false
  end

  def fetch_cover_art_archive(track:, artist:, album:)
    options = []

    begin
      search_term = track.presence || album
      return options if search_term.blank?

      # Search MusicBrainz for recordings/releases
      recording = ScrobbleCacheService.get_musicbrainz_recording(search_term, artist)
      if recording && recording[:releases].present?
        seen_mbids = Set.new

        recording[:releases].first(5).each do |release|
          next unless release[:mbid]
          next if seen_mbids.include?(release[:mbid])

          seen_mbids.add(release[:mbid])
          artwork_url = ScrobbleCacheService.get_cover_art_url(release[:mbid], size: 500)

          if artwork_url.present?
            options << {
              url: artwork_url,
              source: 'cover_art_archive',
              source_display: 'Cover Art Archive',
              album_name: release[:title],
              release_mbid: release[:mbid],
              release_date: release[:date],
              size: 500
            }
          end
        end
      end
    rescue StandardError => e
      Rails.logger.warn("Cover Art Archive search failed: #{e.message}")
    end

    options
  end

  def fetch_discogs_artwork(track:, artist:, album:)
    options = []

    begin
      # Search Discogs
      search_term = album.presence || track
      results = DiscogsService.search(track: search_term, artist: artist, limit: 5)

      return options if results.blank?

      seen_images = Set.new
      results.each do |result|
        cover_image = result[:cover_image]
        next if cover_image.blank? || cover_image.include?('spacer.gif')
        next if seen_images.include?(cover_image)

        seen_images.add(cover_image)
        options << {
          url: cover_image,
          source: 'discogs',
          source_display: 'Discogs',
          album_name: result[:title],
          master_id: result[:master_id],
          year: result[:year]
        }
      end

      # Also fetch from master releases for better quality images
      results.first(2).each do |result|
        master_id = result[:master_id]
        next unless master_id

        master = ScrobbleCacheService.get_discogs_master(master_id)
        next unless master

        cover_image = master[:cover_image]
        next if cover_image.blank? || cover_image.include?('spacer.gif')
        next if seen_images.include?(cover_image)

        seen_images.add(cover_image)
        options << {
          url: cover_image,
          source: 'discogs',
          source_display: 'Discogs (Master)',
          album_name: master[:title],
          master_id: master_id,
          year: master[:year]
        }
      end
    rescue StandardError => e
      Rails.logger.warn("Discogs artwork search failed: #{e.message}")
    end

    options
  end

  def fetch_lastfm_artwork(artist:, album:)
    options = []

    begin
      return options if artist.blank?

      # Get album info from Last.fm if album name provided
      if album.present?
        album_info = LastfmService.get_album_info(artist: artist, album: album)
        if album_info && album_info[:image].present?
          image_url = find_largest_lastfm_image(album_info[:image])
          if image_url.present?
            options << {
              url: image_url,
              source: 'lastfm',
              source_display: 'Last.fm',
              album_name: album_info[:name] || album
            }
          end
        end
      end

      # Also try to get artist top albums for more options
      top_albums = LastfmService.get_artist_top_albums(artist: artist, limit: 3)
      top_albums&.each do |top_album|
        next unless top_album[:image].present?

        image_url = find_largest_lastfm_image(top_album[:image])
        next if image_url.blank?
        next if options.any? { |o| o[:url] == image_url }

        options << {
          url: image_url,
          source: 'lastfm',
          source_display: 'Last.fm',
          album_name: top_album[:name]
        }
      end
    rescue StandardError => e
      Rails.logger.warn("Last.fm artwork search failed: #{e.message}")
    end

    options
  end

  def fetch_audiodb_artwork(track:, artist:, album:)
    options = []

    begin
      return options if artist.blank?

      seen_urls = Set.new

      # Try to find album artwork
      if album.present?
        album_data = ScrobbleCacheService.get_audiodb_album(artist, album)
        if album_data
          add_audiodb_album_images(album_data, options, seen_urls)
        end
      end

      # Try track search to find associated album artwork
      if track.present?
        track_data = ScrobbleCacheService.get_audiodb_track(artist, track)
        if track_data && track_data[:album_id]
          album_data = AudioDbService.get_album(track_data[:album_id])
          if album_data
            add_audiodb_album_images(album_data, options, seen_urls)
          end
        end
      end

      # Also get artist info for additional album options
      artist_data = ScrobbleCacheService.get_audiodb_artist(artist)
      if artist_data && artist_data[:id]
        # Get artist's albums for more artwork options
        albums = AudioDbService.get_artist_albums(artist_data[:id])
        albums.first(3).each do |alb|
          add_audiodb_album_images(alb, options, seen_urls)
        end
      end
    rescue StandardError => e
      Rails.logger.warn("TheAudioDB artwork search failed: #{e.message}")
    end

    options.first(5) # Limit to 5 options from AudioDB
  end

  def add_audiodb_album_images(album_data, options, seen_urls)
    return unless album_data

    # Prefer HQ thumb, then regular thumb
    image_urls = [
      album_data[:album_thumb_hq],
      album_data[:album_thumb],
      album_data[:album_cdart]
    ].compact.reject(&:blank?)

    image_urls.each do |url|
      next if seen_urls.include?(url)
      seen_urls.add(url)

      options << {
        url: url,
        source: 'audiodb',
        source_display: 'TheAudioDB',
        album_name: album_data[:name],
        artist_name: album_data[:artist_name],
        year: album_data[:release_year]
      }
    end
  end

  def find_largest_lastfm_image(images)
    return nil unless images.is_a?(Array)

    # Priority order for image sizes
    size_priority = %w[mega extralarge large medium small]

    size_priority.each do |size|
      image = images.find { |img| img['size'] == size }
      url = image&.dig('#text')
      return url if url.present? && !url.include?('2a96cbd8b46e442fc41c2b86b821562f') # Skip default placeholder
    end

    nil
  end

  def deduplicate_and_sort_artwork(options)
    # Remove duplicates by URL
    seen_urls = Set.new
    unique_options = options.select do |opt|
      next false if seen_urls.include?(opt[:url])
      seen_urls.add(opt[:url])
      true
    end

    # Sort by:
    # 1. Match type (exact matches first)
    # 2. Source priority within each match type
    match_type_priority = {
      'exact' => 0,
      'artist_catalog' => 1
    }

    source_priority = {
      'audiodb' => 0,        # Best for official album artwork
      'cover_art_archive' => 1,
      'discogs' => 2,
      'lastfm' => 3
    }

    unique_options.sort_by do |opt|
      [
        match_type_priority[opt[:match_type]] || 99,
        source_priority[opt[:source]] || 99
      ]
    end
  end

  def check_search_rate_limit
    identifier = current_user&.id || request.remote_ip
    cache_key = "artwork_search_rate:#{identifier}:#{Time.current.beginning_of_minute.to_i}"
    current_count = Rails.cache.read(cache_key) || 0

    if current_count >= SEARCH_RATE_LIMIT_PER_MINUTE
      render json: { error: 'Too many searches. Please wait a moment.' }, status: :too_many_requests
      return
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end
end
