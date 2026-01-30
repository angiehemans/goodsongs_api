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

  def cached_track_search(track:, artist:, limit:)
    cache_key = "discogs:track_search:v3:#{Digest::SHA256.hexdigest("#{track}:#{artist}:#{limit}")}"

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

  def cached_release(release_id)
    cache_key = "discogs:release:#{release_id}"

    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      DiscogsService.get_release(release_id)
    end
  end

  # Search for releases matching the track/artist query.
  # Uses Discogs search results directly instead of fetching master details
  # for each result. Tracklist details are available via GET /discogs/master/:id.
  def search_and_match_tracks(track:, artist:, limit:)
    return [] if track.blank? && artist.blank?

    results = DiscogsService.search(track: track, artist: artist, limit: limit * 2)

    return [] if results.blank?

    # Dedupe by master_id
    seen_masters = Set.new
    unique_results = results.select do |r|
      next false unless r[:master_id]
      next false if seen_masters.include?(r[:master_id])
      seen_masters.add(r[:master_id])
      true
    end

    # Score and sort to prioritize studio albums
    scored = unique_results.map do |release|
      { release: release, score: score_release(release) }
    end

    scored
      .sort_by { |r| -r[:score] }
      .first(limit)
      .map { |r| format_search_result(r[:release], track) }
  end

  def format_search_result(release, track_query)
    {
      song_name: track_query,
      band_name: release[:artist],
      album_title: release[:title],
      release_year: release[:year],
      artwork_url: release[:cover_image],
      master_id: release[:master_id],
      discogs_url: "https://www.discogs.com/master/#{release[:master_id]}",
      genre: release[:genre],
      style: release[:style]
    }
  end

  def score_release(release)
    score = 0
    format = release[:format]&.downcase || ''
    title = release[:title]&.downcase || ''

    # Penalize non-studio albums
    score -= 200 if title.include?('live at') || title.include?('live in') || title.include?('bootleg')
    score -= 150 if title.include?('compilation') || title.include?('best of') || title.include?('greatest hits')
    score -= 100 if title.include?('acoustic') || title.include?('unplugged')
    score -= 100 if title.include?(' ep') || title.end_with?(' ep')
    score -= 50 if title.include?('remix') || title.include?('single')
    score -= 50 if title.include?('special') || title.include?('deluxe')

    # Prefer vinyl/LP (often studio albums)
    score += 30 if format.include?('lp') || format.include?('vinyl')

    # Slight preference for older releases (likely the original)
    year = release[:year].to_i
    score += 10 if year > 0 && year < 2005

    score
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
