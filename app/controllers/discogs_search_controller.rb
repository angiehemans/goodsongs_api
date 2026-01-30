# frozen_string_literal: true

class DiscogsSearchController < ApplicationController
  include ResourceController

  skip_before_action :require_onboarding_completed
  before_action :check_search_rate_limit, only: [:search]

  SEARCH_RATE_LIMIT_PER_MINUTE = 30
  DEFAULT_LIMIT = 10
  MAX_LIMIT = 25

  # GET /discogs/search?track=...&artist=...&limit=...
  # Search for songs - returns albums containing the track, prioritizing studio albums
  def search
    track = params[:track]&.strip.presence
    artist = params[:artist]&.strip.presence

    if track.blank? && artist.blank?
      render json: { error: 'Track name or artist name is required' }, status: :bad_request
      return
    end

    limit = [[params[:limit]&.to_i || DEFAULT_LIMIT, MAX_LIMIT].min, 1].max

    begin
      formatted = cached_track_search(track: track, artist: artist, limit: limit)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("Discogs search failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    json_response({
      results: formatted,
      query: { track: track, artist: artist }
    })
  end

  # GET /discogs/master/:id
  # Get master release details with tracklist
  def master
    master_id = params[:id]

    if master_id.blank?
      render json: { error: 'Master ID is required' }, status: :bad_request
      return
    end

    begin
      master_data = cached_master(master_id)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("Discogs master fetch failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    if master_data.nil?
      render json: { error: 'Release not found' }, status: :not_found
      return
    end

    json_response({
      master: master_data,
      tracks: master_data[:tracklist]&.map { |t| format_track_for_review(t, master_data) }
    })
  end

  # GET /discogs/release/:id
  # Get release details with tracklist (for non-master releases)
  def release
    release_id = params[:id]

    if release_id.blank?
      render json: { error: 'Release ID is required' }, status: :bad_request
      return
    end

    begin
      release_data = cached_release(release_id)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("Discogs release fetch failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    if release_data.nil?
      render json: { error: 'Release not found' }, status: :not_found
      return
    end

    json_response({
      release: release_data,
      tracks: release_data[:tracklist]&.map { |t| format_track_for_review(t, release_data) }
    })
  end

  private

  # Cache the full track search result (includes tracklist fetching)
  def cached_track_search(track:, artist:, limit:)
    cache_key = "discogs:track_search:v2:#{Digest::SHA256.hexdigest("#{track}:#{artist}:#{limit}")}"

    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      search_and_match_tracks(track: track, artist: artist, limit: limit)
    end
  end

  def cached_master(master_id)
    cache_key = "discogs:master:#{master_id}"

    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      DiscogsService.get_master(master_id)
    end
  end

  # Search for releases and find matching tracks - prioritizes albums over singles
  def search_and_match_tracks(track:, artist:, limit:)
    return [] if track.blank? && artist.blank?

    # Two search strategies combined:
    # 1. Search by track name to find releases containing that track
    # 2. Search by artist + album-style query to find main albums
    track_results = DiscogsService.search(track: track, artist: artist, limit: 20) if track.present?
    track_results ||= []

    # Also search for artist's main releases (helps find studio albums)
    artist_results = []
    if artist.present?
      artist_results = DiscogsService.search(artist: artist, query: nil, limit: 10)
    end

    # Combine and dedupe by master_id
    seen_masters = Set.new
    all_results = []

    (track_results + artist_results).each do |r|
      next unless r[:master_id]
      next if seen_masters.include?(r[:master_id])
      seen_masters.add(r[:master_id])
      all_results << r
    end

    return [] if all_results.blank?

    matching_tracks = []
    normalized_query = normalize_for_matching(track) if track.present?

    # Sort to prioritize likely studio albums
    sorted_results = all_results.sort_by do |release|
      score = 0
      format = release[:format]&.downcase || ''
      title = release[:title]&.downcase || ''

      # Heavy penalty for obvious non-albums
      score += 200 if title.include?('live at') || title.include?('live in')
      score += 200 if title.include?('bootleg')
      score += 150 if title.include?('compilation') || title.include?('best of') || title.include?('greatest hits')
      score += 100 if title.include?('acoustic') || title.include?('unplugged')
      score += 100 if title.include?(' ep') || title.end_with?(' ep')
      score += 50 if title.include?('remix')
      score += 50 if title.include?('special') || title.include?('deluxe')

      # Prefer vinyl/LP (often studio albums)
      score -= 30 if format.include?('lp') || format.include?('vinyl')

      # Slight preference for older releases
      year = release[:year].to_i
      score -= 10 if year > 0 && year < 2005

      score
    end

    # Check up to 10 releases for matching tracks
    sorted_results.first(10).each do |release|
      next unless release[:master_id]

      master_data = cached_master(release[:master_id])
      next unless master_data&.dig(:tracklist)

      # If no track query, just return the release info
      if track.blank?
        matching_tracks << format_result(release, master_data, nil)
        next
      end

      # Find matching track in tracklist
      master_data[:tracklist].each do |t|
        next unless t[:title]
        normalized_title = normalize_for_matching(t[:title])

        if track_matches?(normalized_title, normalized_query)
          matching_tracks << format_result(release, master_data, t)
          break  # Only one match per release
        end
      end

      break if matching_tracks.size >= limit
    end

    # Score and sort results - prefer albums with exact track matches
    matching_tracks
      .sort_by { |t| -calculate_result_score(t, normalized_query) }
      .first(limit)
  end

  def format_result(release, master_data, track)
    {
      song_name: track&.dig(:title),
      band_name: master_data[:artist] || release[:artist],
      album_title: master_data[:title] || release[:title],
      release_year: master_data[:year] || release[:year],
      artwork_url: master_data[:cover_image] || release[:cover_image],
      discogs_url: "https://www.discogs.com/master/#{release[:master_id]}",
      genre: release[:genre],
      style: release[:style]
    }
  end

  def track_matches?(normalized_title, normalized_query)
    return false if normalized_query.blank?
    normalized_title.include?(normalized_query) || normalized_query.include?(normalized_title)
  end

  def calculate_result_score(result, track_query)
    score = 0
    song = normalize_for_matching(result[:song_name])
    album = normalize_for_matching(result[:album_title])

    # Exact track match is best
    score += 100 if song == track_query

    # Penalize if album title suggests it's a single/compilation
    score -= 50 if album.include?('single')
    score -= 50 if album.include?('compilation')
    score -= 30 if album.include?('live')
    score -= 30 if album.include?('acoustic')
    score -= 30 if album.include?('remix')
    score -= 20 if album.include?(' ep')

    # Prefer older releases (likely the original album)
    year = result[:release_year].to_i
    score += 10 if year > 0 && year < 2010

    score
  end

  def normalize_for_matching(str)
    str.to_s.downcase.gsub(/[^a-z0-9\s]/, '').strip
  end

  def format_track_for_review(track, release_data)
    {
      position: track[:position],
      song_name: track[:title],
      band_name: track[:artists]&.first || release_data[:artist],
      release_name: release_data[:title],
      release_year: release_data[:year],
      artwork_url: release_data[:cover_image],
      duration: track[:duration],
      # Prefill object ready for review form
      prefill: {
        song_name: track[:title],
        band_name: track[:artists]&.first || release_data[:artist],
        artwork_url: release_data[:cover_image],
        song_link: nil
      }
    }
  end

  def check_search_rate_limit
    identifier = current_user&.id || request.remote_ip
    cache_key = "discogs_search_rate:#{identifier}:#{Time.current.beginning_of_minute.to_i}"
    current_count = Rails.cache.read(cache_key) || 0

    if current_count >= SEARCH_RATE_LIMIT_PER_MINUTE
      render json: { error: 'Too many searches. Please wait a moment.' }, status: :too_many_requests
      return
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end
end
