# frozen_string_literal: true

class MusicbrainzSearchController < ApplicationController
  include ResourceController

  skip_before_action :require_onboarding_completed
  before_action :check_search_rate_limit, only: [:search]

  SEARCH_RATE_LIMIT_PER_MINUTE = 10
  DEFAULT_LIMIT = 5
  MAX_LIMIT = 20

  # GET /musicbrainz/search?track=...&artist=...&limit=...
  def search
    track = params[:track]&.strip

    if track.blank?
      render json: { error: 'Track name is required' }, status: :bad_request
      return
    end

    artist = params[:artist]&.strip.presence
    limit = [[params[:limit]&.to_i || DEFAULT_LIMIT, MAX_LIMIT].min, 1].max

    begin
      results = ScrobbleCacheService.get_search_results(track, artist, limit: limit)
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
      Rails.logger.warn("MusicBrainz search failed: #{e.message}")
      render json: { error: 'Music search is temporarily unavailable. Please try again.' }, status: :service_unavailable
      return
    end

    json_response({
      results: format_search_results(results),
      query: { track: track, artist: artist }
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
      primary_release = r[:releases]&.first
      release_mbid = primary_release&.dig(:mbid)

      {
        mbid: r[:mbid],
        song_name: r[:title],
        band_name: primary_artist&.dig(:name),
        band_musicbrainz_id: primary_artist&.dig(:mbid),
        release_mbid: release_mbid,
        release_name: primary_release&.dig(:title),
        release_date: primary_release&.dig(:date) || r[:first_release_date],
        artwork_url: release_mbid ? "https://coverartarchive.org/release/#{release_mbid}/front-500" : nil,
        score: r[:score],
        duration_ms: r[:length]
      }
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
