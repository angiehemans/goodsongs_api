#!/usr/bin/env ruby
# frozen_string_literal: true

# fetch_cover_art.rb
# Fetches cover art URLs from Cover Art Archive for albums that have a musicbrainz_release_id
# 
# NOTE: Cover Art Archive has rate limits. This script respects a 1 request/second limit.
# For large batches, consider running overnight.

require 'net/http'
require 'json'
require 'optparse'

class CoverArtFetcher
  COVER_ART_BASE = 'https://coverartarchive.org/release-group'
  RATE_LIMIT_DELAY = 1.0 # seconds between requests
  
  def initialize(options)
    @batch_size = options[:batch_size] || 100
    @dry_run = options[:dry_run] || false
    @verbose = options[:verbose] || false
    
    @total_processed = 0
    @total_found = 0
    @total_not_found = 0
    @total_errors = 0
  end

  def fetch_all
    puts "Fetching cover art for albums without cover_art_url..."
    puts "Batch size: #{@batch_size}"
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts ""
    
    loop do
      # Get batch of albums needing cover art
      albums = Album.where(cover_art_url: nil)
                    .where.not(musicbrainz_release_id: nil)
                    .limit(@batch_size)
      
      break if albums.empty?
      
      albums.each do |album|
        fetch_for_album(album)
        @total_processed += 1
        
        # Rate limiting
        sleep(RATE_LIMIT_DELAY)
      end
      
      puts "Progress: #{@total_processed} processed, #{@total_found} found, #{@total_not_found} not found, #{@total_errors} errors"
    end
    
    puts ""
    puts "Complete!"
    puts "Total processed: #{@total_processed}"
    puts "Cover art found: #{@total_found}"
    puts "Not found: #{@total_not_found}"
    puts "Errors: #{@total_errors}"
  end

  def fetch_for_album(album)
    mbid = album.musicbrainz_release_id
    url = "#{COVER_ART_BASE}/#{mbid}"
    
    puts "Fetching: #{album.name} (#{mbid})" if @verbose
    
    begin
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      case response.code.to_i
      when 200
        data = JSON.parse(response.body)
        cover_url = extract_cover_url(data)
        
        if cover_url
          unless @dry_run
            album.update!(cover_art_url: cover_url)
          end
          @total_found += 1
          puts "  Found: #{cover_url}" if @verbose
        else
          @total_not_found += 1
          puts "  No front cover in response" if @verbose
        end
        
      when 404
        @total_not_found += 1
        puts "  Not found (404)" if @verbose
        
      when 503
        # Rate limited - wait and retry
        puts "  Rate limited, waiting 5 seconds..."
        sleep(5)
        fetch_for_album(album) # Retry
        
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

  def extract_cover_url(data)
    images = data['images'] || []
    
    # Find the front cover
    front = images.find { |img| img['front'] == true }
    
    # Fall back to first image if no front specified
    front ||= images.first
    
    return nil unless front
    
    # Prefer 500px thumbnail, fall back to full size
    thumbnails = front['thumbnails'] || {}
    thumbnails['500'] || thumbnails['large'] || front['image']
  end
end

# Check if we're running in Rails context
unless defined?(Album)
  puts "This script must be run in Rails context:"
  puts "  rails runner fetch_cover_art.rb [options]"
  puts ""
  puts "Or with bundle exec:"
  puts "  bundle exec rails runner fetch_cover_art.rb [options]"
  exit 1
end

# Parse options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: rails runner fetch_cover_art.rb [options]"
  
  opts.on("-b", "--batch-size N", Integer, "Albums to process per batch (default: 100)") do |v|
    options[:batch_size] = v
  end
  
  opts.on("-n", "--dry-run", "Don't actually update records") do
    options[:dry_run] = true
  end
  
  opts.on("-v", "--verbose", "Print details for each album") do
    options[:verbose] = true
  end
  
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

fetcher = CoverArtFetcher.new(options)
fetcher.fetch_all
