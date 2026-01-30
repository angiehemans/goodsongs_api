# frozen_string_literal: true

class MusicbrainzSearchController < ApplicationController
  include ResourceController

  skip_before_action :require_onboarding_completed
  before_action :check_search_rate_limit, only: [:search]

  SEARCH_RATE_LIMIT_PER_MINUTE = 10
  DEFAULT_LIMIT = 5
  MAX_LIMIT = 20

  # Available sort options
  SORT_OPTIONS = %w[relevance releases date original].freeze

  # GET /musicbrainz/search?track=...&artist=...&limit=...&sort=...
  # - track: song name (optional if artist provided)
  # - artist: band/artist name (optional if track provided)
  # - q: combined search query (searches both track and artist)
  # - sort: relevance (default), releases (most releases first), date (oldest first)
  def search
    track = params[:track]&.strip.presence
    artist = params[:artist]&.strip.presence
    query = params[:q]&.strip.presence

    # If q is provided, use it for both track and artist search
    if query.present?
      track = query
      artist = query
    end

    if track.blank? && artist.blank?
      render json: { error: 'Track name, artist name, or search query is required' }, status: :bad_request
      return
    end

    limit = [[params[:limit]&.to_i || DEFAULT_LIMIT, MAX_LIMIT].min, 1].max
    sort = params[:sort]&.downcase
    sort = 'original' unless SORT_OPTIONS.include?(sort)  # Default to original releases

    begin
      # Fetch more results to find original releases, then trim to limit
      fetch_limit = [limit * 3, MAX_LIMIT].min
      results = fetch_recordings(track, artist, fetch_limit)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("MusicBrainz search failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    formatted = format_search_results(results)

    # Deduplicate by song name + artist, keeping the best version
    formatted = deduplicate_recordings(formatted)

    # Filter out non-official releases if requested
    if params[:official_only] == 'true'
      formatted = formatted.select { |r| r[:release_status] == 'Official' && r[:is_original_release] }
    end

    sorted = sort_results(formatted, sort)

    json_response({
      results: sorted.first(limit),
      query: { track: track, artist: artist, q: query, sort: sort, official_only: params[:official_only] }
    })
  end

  # GET /musicbrainz/recording/:mbid
  def recording
    mbid = params[:mbid]

    if mbid.blank?
      render json: { error: 'Recording MBID is required' }, status: :bad_request
      return
    end

    begin
      recording_data = ScrobbleCacheService.get_recording_detail(mbid)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("MusicBrainz recording fetch failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    if recording_data.nil?
      render json: { error: 'Recording not found' }, status: :not_found
      return
    end

    artwork_url = fetch_artwork(recording_data)

    json_response({
      recording: format_recording_detail(recording_data, artwork_url),
      prefill: build_prefill(recording_data, artwork_url)
    })
  end

  private

  def format_search_results(results)
    return [] unless results.is_a?(Array)

    results.map do |r|
      primary_artist = r[:artists]&.first
      releases = r[:releases] || []

      # Find the best release (prefer official album releases)
      best_release = find_best_release(releases)
      release_mbid = best_release&.dig(:mbid)
      releases_count = releases.size

      {
        mbid: r[:mbid],
        song_name: r[:title],
        band_name: primary_artist&.dig(:name),
        band_musicbrainz_id: primary_artist&.dig(:mbid),
        release_mbid: release_mbid,
        release_name: best_release&.dig(:title),
        release_date: best_release&.dig(:date) || r[:first_release_date],
        release_type: best_release&.dig(:release_type),
        release_status: best_release&.dig(:status),
        artwork_url: release_mbid ? "https://coverartarchive.org/release/#{release_mbid}/front-500" : nil,
        score: r[:score],
        duration_ms: r[:length],
        releases_count: releases_count,
        is_original_release: best_release&.dig(:is_original) || false
      }
    end
  end

  def find_best_release(releases)
    return nil if releases.blank?

    # Score each release - higher is better
    scored = releases.map do |release|
      score = 0

      # Strongly prefer Official status
      case release[:status]
      when 'Official'
        score += 100
      when 'Promotion'
        score += 20
      when 'Bootleg'
        score -= 100
      end

      # Prefer Album or Single over Compilation/Soundtrack
      release_type = release[:release_type]&.downcase
      if release_type == 'album'
        score += 50
      elsif release_type == 'single' || release_type == 'ep'
        score += 40
      elsif release_type.nil?
        score += 10 # Unknown type, slight bonus over known bad types
      end

      # Check secondary types
      secondary_types = (release[:secondary_types] || []).map(&:downcase)

      if secondary_types.empty?
        # No secondary types = likely original release
        score += 30
      else
        # Penalize compilations, soundtracks, remixes, live versions
        score -= 50 if secondary_types.include?('compilation')
        score -= 50 if secondary_types.include?('soundtrack')
        score -= 40 if secondary_types.include?('live')
        score -= 40 if secondary_types.include?('remix')
        score -= 30 if secondary_types.include?('dj-mix')
        score -= 20 if secondary_types.include?('mixtape/street')
      end

      # Prefer earlier releases (likely the original)
      if release[:date].present?
        score += 10
      end

      # Mark as original if: Official + Album/Single + No bad secondary types
      is_original = release[:status] == 'Official' &&
                    %w[album single ep].include?(release_type) &&
                    secondary_types.empty?

      { release: release.merge(is_original: is_original), score: score }
    end

    # Return the highest scored release
    best = scored.max_by { |s| s[:score] }
    best&.dig(:release)
  end

  def deduplicate_recordings(results)
    # Group by normalized song name + artist name
    grouped = results.group_by do |r|
      key = "#{r[:song_name]&.downcase&.strip}:#{r[:band_name]&.downcase&.strip}"
      # Remove common suffixes like "(live)", "(radio edit)", etc.
      key.gsub(/\s*\((?:live|radio|acoustic|demo|remix|edit|version|remaster).*\)\s*/i, '')
    end

    # For each group, keep the one with the best release (highest score)
    grouped.map do |_key, recordings|
      recordings.max_by do |r|
        score = 0
        score += 100 if r[:is_original_release]
        score += 50 if r[:release_status] == 'Official'
        score -= 50 if r[:release_status] == 'Bootleg'
        score += r[:score].to_i  # Use MusicBrainz relevance as tiebreaker
        score
      end
    end
  end

  def sort_results(results, sort)
    case sort
    when 'releases'
      # Most releases first (proxy for popularity)
      results.sort_by { |r| -(r[:releases_count] || 0) }
    when 'date'
      # Oldest first (more established songs)
      results.sort_by { |r| r[:release_date] || '9999' }
    when 'original'
      # Prioritize original album releases
      results.sort_by do |r|
        score = 0
        score -= 100 if r[:is_original_release]
        score -= 50 if r[:release_status] == 'Official'
        score += 50 if r[:release_status] == 'Bootleg'
        score
      end
    else
      # Default: by relevance score (already sorted from API)
      results
    end
  end

  def fetch_recordings(track, artist, limit)
    # Build cache key based on what's provided
    cache_key = "musicbrainz:search:#{Digest::SHA256.hexdigest("#{track}:#{artist}:#{limit}")}"

    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      MusicbrainzService.search_recording_flexible(track: track, artist: artist, limit: limit)
    end
  end

  def format_recording_detail(recording_data, artwork_url)
    primary_artist = recording_data[:artists]&.first
    primary_release = recording_data[:releases]&.first

    {
      mbid: recording_data[:mbid],
      song_name: recording_data[:title],
      band_name: primary_artist&.dig(:name),
      band_musicbrainz_id: primary_artist&.dig(:mbid),
      artwork_url: artwork_url,
      song_link: nil,
      release: primary_release ? {
        mbid: primary_release[:mbid],
        title: primary_release[:title],
        date: primary_release[:date]
      } : nil,
      isrcs: recording_data[:isrcs] || [],
      duration_ms: recording_data[:length]
    }
  end

  def build_prefill(recording_data, artwork_url)
    primary_artist = recording_data[:artists]&.first

    {
      song_name: recording_data[:title],
      band_name: primary_artist&.dig(:name),
      artwork_url: artwork_url,
      song_link: nil,
      band_musicbrainz_id: primary_artist&.dig(:mbid)
    }
  end

  def fetch_artwork(recording_data)
    primary_release = recording_data[:releases]&.first
    return nil unless primary_release&.dig(:mbid)

    ScrobbleCacheService.get_cover_art_url(primary_release[:mbid], size: 500)
  end

  def check_search_rate_limit
    cache_key = "musicbrainz_search_rate:#{current_user.id}:#{Time.current.beginning_of_minute.to_i}"
    current_count = Rails.cache.read(cache_key) || 0

    if current_count >= SEARCH_RATE_LIMIT_PER_MINUTE
      render json: { error: 'Too many searches. Please wait a moment.' }, status: :too_many_requests
      return
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end
end
