#!/usr/bin/env ruby
# frozen_string_literal: true

# link_tracks_to_albums.rb
# Links tracks to albums by querying MusicBrainz API for recording -> release-group relationships
#
# NOTE: MusicBrainz API requires 1 request/second rate limit.
# This script is designed to run incrementally over time.

require 'net/http'
require 'json'
require 'optparse'
require 'cgi'

class TrackAlbumLinker
  MUSICBRAINZ_BASE = 'https://musicbrainz.org/ws/2'
  USER_AGENT = 'GoodSongs/1.0 (https://goodsongs.app; contact@goodsongs.app)'
  RATE_LIMIT_DELAY = 1.1 # slightly over 1 second to be safe
  
  def initialize(options)
    @batch_size = options[:batch_size] || 100
    @dry_run = options[:dry_run] || false
    @verbose = options[:verbose] || false
    
    @total_processed = 0
    @total_linked = 0
    @total_not_found = 0
    @total_errors = 0
    
    # Cache album lookups to avoid duplicate API calls
    @album_cache = {}
  end

  def link_all
    puts "Linking tracks to albums..."
    puts "Batch size: #{@batch_size}"
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts ""
    
    loop do
      # Get batch of tracks without album_id that have a musicbrainz_recording_id
      tracks = Track.where(album_id: nil)
                    .where.not(musicbrainz_recording_id: nil)
                    .limit(@batch_size)
      
      break if tracks.empty?
      
      tracks.each do |track|
        link_track(track)
        @total_processed += 1
        
        # Rate limiting
        sleep(RATE_LIMIT_DELAY)
        
        # Progress every 50 tracks
        if @total_processed % 50 == 0
          puts "Progress: #{@total_processed} processed, #{@total_linked} linked, #{@total_not_found} not found"
        end
      end
    end
    
    puts ""
    puts "Complete!"
    puts "Total processed: #{@total_processed}"
    puts "Successfully linked: #{@total_linked}"
    puts "Not found: #{@total_not_found}"
    puts "Errors: #{@total_errors}"
  end

  def link_track(track)
    recording_mbid = track.musicbrainz_recording_id
    
    puts "Processing: #{track.name} (#{recording_mbid})" if @verbose
    
    begin
      # Query MusicBrainz for recording with release-groups
      uri = URI("#{MUSICBRAINZ_BASE}/recording/#{recording_mbid}?inc=release-groups&fmt=json")
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT
      
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      
      case response.code.to_i
      when 200
        data = JSON.parse(response.body)
        release_groups = data['release-groups'] || []
        
        if release_groups.empty?
          @total_not_found += 1
          puts "  No release groups found" if @verbose
          return
        end
        
        # Find matching album in our database
        album = find_matching_album(release_groups, track)
        
        if album
          unless @dry_run
            track.update!(album_id: album.id)
          end
          @total_linked += 1
          puts "  Linked to: #{album.name}" if @verbose
        else
          @total_not_found += 1
          puts "  No matching album in database" if @verbose
        end
        
      when 404
        @total_not_found += 1
        puts "  Recording not found (404)" if @verbose
        
      when 503
        # Rate limited
        puts "  Rate limited, waiting 5 seconds..."
        sleep(5)
        link_track(track) # Retry
        
      else
        @total_errors += 1
        puts "  Unexpected response: #{response.code}" if @verbose
      end
      
    rescue StandardError => e
      @total_errors += 1
      puts "  Error: #{e.message}" if @verbose
    end
  end

  private

  def find_matching_album(release_groups, track)
    # Try to find an album from the same band first
    release_groups.each do |rg|
      mbid = rg['id']
      
      # Check cache first
      if @album_cache.key?(mbid)
        album = @album_cache[mbid]
        return album if album && album.band_id == track.band_id
        next
      end
      
      # Look up in database
      album = Album.find_by(musicbrainz_release_id: mbid)
      @album_cache[mbid] = album
      
      # Prefer album from same band
      return album if album && album.band_id == track.band_id
    end
    
    # If no album from same band, return any matching album
    release_groups.each do |rg|
      album = @album_cache[rg['id']]
      return album if album
    end
    
    nil
  end
end

# Check if we're running in Rails context
unless defined?(Track) && defined?(Album)
  puts "This script must be run in Rails context:"
  puts "  rails runner link_tracks_to_albums.rb [options]"
  exit 1
end

# Parse options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: rails runner link_tracks_to_albums.rb [options]"
  
  opts.on("-b", "--batch-size N", Integer, "Tracks to process per batch (default: 100)") do |v|
    options[:batch_size] = v
  end
  
  opts.on("-n", "--dry-run", "Don't actually update records") do
    options[:dry_run] = true
  end
  
  opts.on("-v", "--verbose", "Print details for each track") do
    options[:verbose] = true
  end
  
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

linker = TrackAlbumLinker.new(options)
linker.link_all
