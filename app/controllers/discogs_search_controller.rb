# frozen_string_literal: true

class DiscogsSearchController < ApplicationController
  include ResourceController

  skip_before_action :require_onboarding_completed
  before_action :check_search_rate_limit, only: [:search]

  SEARCH_RATE_LIMIT_PER_MINUTE = 30
  DEFAULT_LIMIT = 10
  MAX_LIMIT = 25

  # GET /discogs/search?track=...&artist=...&limit=...
  # Search for songs - uses local DB first, then AudioDB, then Discogs
  def search
    track = params[:track]&.strip.presence
    artist = params[:artist]&.strip.presence

    if track.blank? && artist.blank?
      render json: { error: 'Track name or artist name is required' }, status: :bad_request
      return
    end

    limit = [[params[:limit]&.to_i || DEFAULT_LIMIT, MAX_LIMIT].min, 1].max

    begin
      # Use the fast song search service (local DB → AudioDB → Discogs)
      results = SongSearchService.search(track: track, artist: artist, limit: limit)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("Song search failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    json_response({
      results: results,
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
