# frozen_string_literal: true

namespace :streaming_links do
  desc "Backfill streaming links for tracks with reviews that have ISRCs"
  task backfill: :environment do
    limit = ENV.fetch("LIMIT", 100).to_i
    dry_run = ENV.fetch("DRY_RUN", "false") == "true"

    puts "[Streaming Links] Starting backfill..."
    puts "[Streaming Links] Limit: #{limit}"
    puts "[Streaming Links] Dry run: #{dry_run}"

    # Find tracks with reviews that have ISRCs but no streaming links fetched yet
    tracks = Track.joins(:reviews)
                  .where.not(isrc: nil)
                  .where(streaming_links_fetched_at: nil)
                  .distinct
                  .limit(limit)

    total = tracks.count
    puts "[Streaming Links] Found #{total} tracks to enrich"

    if dry_run
      puts "[Streaming Links] Dry run - would queue #{total} jobs"
      tracks.each do |track|
        puts "  - Track #{track.id}: '#{track.name}' (ISRC: #{track.isrc})"
      end
    else
      queued = 0
      tracks.find_each do |track|
        StreamingLinksEnrichmentJob.perform_later(track.id)
        queued += 1
        print "\r[Streaming Links] Queued #{queued}/#{total} jobs..."
      end
      puts "\n[Streaming Links] Backfill complete! Queued #{queued} jobs."
      puts "[Streaming Links] Jobs will process at ~10/minute due to rate limiting."
      puts "[Streaming Links] Estimated completion time: ~#{(queued / 10.0).ceil} minutes"
    end
  end

  desc "Show streaming links enrichment statistics"
  task stats: :environment do
    puts "[Streaming Links] Statistics"
    puts "=" * 50

    total_tracks = Track.count
    tracks_with_isrc = Track.where.not(isrc: nil).count
    tracks_fetched = Track.where.not(streaming_links_fetched_at: nil).count
    tracks_with_links = Track.where("streaming_links != '{}'::jsonb").count
    tracks_needing_fetch = Track.where.not(isrc: nil).where(streaming_links_fetched_at: nil).count

    # Tracks with reviews
    reviewed_tracks = Track.joins(:reviews).distinct.count
    reviewed_with_isrc = Track.joins(:reviews).where.not(isrc: nil).distinct.count
    reviewed_fetched = Track.joins(:reviews).where.not(streaming_links_fetched_at: nil).distinct.count
    reviewed_needing_fetch = Track.joins(:reviews).where.not(isrc: nil).where(streaming_links_fetched_at: nil).distinct.count

    puts "\nAll Tracks:"
    puts "  Total tracks:                #{total_tracks}"
    puts "  Tracks with ISRC:            #{tracks_with_isrc} (#{percentage(tracks_with_isrc, total_tracks)})"
    puts "  Tracks fetched:              #{tracks_fetched} (#{percentage(tracks_fetched, total_tracks)})"
    puts "  Tracks with links:           #{tracks_with_links} (#{percentage(tracks_with_links, tracks_fetched)} of fetched)"
    puts "  Tracks needing fetch:        #{tracks_needing_fetch}"

    puts "\nReviewed Tracks (priority):"
    puts "  Total reviewed tracks:       #{reviewed_tracks}"
    puts "  With ISRC:                   #{reviewed_with_isrc} (#{percentage(reviewed_with_isrc, reviewed_tracks)})"
    puts "  Already fetched:             #{reviewed_fetched} (#{percentage(reviewed_fetched, reviewed_with_isrc)} of ISRC)"
    puts "  Needing fetch:               #{reviewed_needing_fetch}"

    if reviewed_needing_fetch > 0
      estimated_time = (reviewed_needing_fetch / 10.0).ceil
      puts "\n  Estimated backfill time:     ~#{estimated_time} minutes (at 10 req/min)"
    end

    # Platform breakdown
    if tracks_with_links > 0
      puts "\nPlatform Coverage (of tracks with links):"
      OdesliService::CORE_PLATFORMS.each do |platform|
        count = Track.where("streaming_links ? :platform", platform: platform).count
        puts "  #{platform.ljust(15)} #{count} (#{percentage(count, tracks_with_links)})"
      end
    end
  end

  private

  def percentage(count, total)
    return "0%" if total.zero?
    "#{(count.to_f / total * 100).round(1)}%"
  end
end
