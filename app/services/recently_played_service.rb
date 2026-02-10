# frozen_string_literal: true

# Aggregates recently played tracks from multiple sources (Last.fm, local scrobbles, etc.)
# Fetches from providers in parallel, merges by played_at, and deduplicates consecutive tracks.
class RecentlyPlayedService
  # Registered providers - add new sources here
  PROVIDERS = [
    RecentlyPlayed::LastfmProvider,
    RecentlyPlayed::ScrobbleProvider
    # RecentlyPlayed::AppleMusicProvider  # Future: add when implemented
  ].freeze

  # Tracks played within this window are considered consecutive duplicates
  DEDUP_THRESHOLD_SECONDS = 300 # 5 minutes

  def initialize(user)
    @user = user
    @providers = PROVIDERS.map(&:new)
  end

  # Fetch recently played tracks from all enabled sources
  # @param limit [Integer] maximum tracks to return (default: 20)
  # @param sources [Array<Symbol>, nil] filter to specific sources, e.g. [:lastfm, :scrobble]
  # @return [Hash] { tracks: [...], sources: [...] }
  def fetch(limit: 20, sources: nil)
    active_providers = filter_providers(sources)

    # Fetch from all providers in parallel
    all_tracks = fetch_parallel(active_providers, limit: limit)

    # Merge all tracks and sort by played_at (descending), now_playing first
    merged = merge_tracks(all_tracks)

    # Deduplicate consecutive plays of the same track
    deduped = deduplicate_consecutive(merged)

    # Limit final result
    final_tracks = deduped.first(limit)

    {
      tracks: format_response(final_tracks),
      sources: active_providers.map(&:source_name)
    }
  end

  private

  def filter_providers(sources)
    providers = @providers.select { |p| p.enabled?(@user) }

    if sources.present?
      source_symbols = Array(sources).map(&:to_sym)
      providers = providers.select { |p| source_symbols.include?(p.source_name) }
    end

    providers
  end

  def fetch_parallel(providers, limit:)
    return [] if providers.empty?

    # Use threads to fetch from all providers concurrently
    threads = providers.map do |provider|
      Thread.new do
        Thread.current[:result] = provider.fetch(@user, limit: limit)
      rescue StandardError => e
        Rails.logger.error("RecentlyPlayedService: #{provider.source_name} failed: #{e.message}")
        Thread.current[:result] = []
      end
    end

    # Wait for all threads and collect results
    threads.map do |thread|
      thread.join
      thread[:result] || []
    end.flatten
  end

  def merge_tracks(tracks)
    # Sort by: now_playing first, then by played_at descending
    tracks.sort_by do |track|
      [
        track[:now_playing] ? 0 : 1,
        track[:played_at] ? -track[:played_at].to_i : 0
      ]
    end
  end

  def deduplicate_consecutive(tracks)
    tracks.each_with_object([]) do |track, result|
      last = result.last

      # Skip if same track played consecutively within threshold
      if last && same_track?(track, last) && within_threshold?(track, last)
        # Keep the more recent one (which is already in result)
        next
      end

      result << track
    end
  end

  def same_track?(a, b)
    return false if a[:track_name].blank? || b[:track_name].blank?

    a[:track_name].downcase.strip == b[:track_name].downcase.strip &&
      a[:artist_name].to_s.downcase.strip == b[:artist_name].to_s.downcase.strip
  end

  def within_threshold?(a, b)
    return true if a[:now_playing] || b[:now_playing]
    return false if a[:played_at].nil? || b[:played_at].nil?

    (a[:played_at].to_i - b[:played_at].to_i).abs < DEDUP_THRESHOLD_SECONDS
  end

  def format_response(tracks)
    tracks.map do |track|
      {
        name: track[:track_name],
        artist: track[:artist_name],
        album: track[:album_name],
        played_at: track[:played_at]&.iso8601,
        now_playing: track[:now_playing],
        source: track[:source],
        mbid: track[:mbid],
        album_art_url: track[:album_art_url],
        loved: track[:loved],
        scrobble_id: track[:scrobble_id]
      }.compact
    end
  end
end
