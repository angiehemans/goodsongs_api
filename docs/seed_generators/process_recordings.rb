#!/usr/bin/env ruby
# frozen_string_literal: true

# process_recordings.rb
# Processes MusicBrainz recording JSON dump and generates Rails seed files for tracks table

require 'json'
require 'optparse'
require 'fileutils'
require 'securerandom'
require 'time'

class RecordingProcessor
  BATCH_SIZE = 10_000
  
  # Minimum duration to filter out sound effects, intros, etc. (30 seconds)
  MIN_DURATION_MS = 30_000

  def initialize(options)
    @input_path = options[:input]
    @output_dir = options[:output]
    @bands_index_path = options[:bands_index]
    @limit = options[:limit]
    @min_duration = options[:min_duration] || MIN_DURATION_MS
    
    @tracks = []
    @file_counter = 1
    @total_processed = 0
    @total_skipped = 0
    @skipped_no_artist = 0
    @skipped_too_short = 0
    
    FileUtils.mkdir_p(@output_dir)
    
    # Load bands index to look up band IDs
    @bands_index = load_bands_index
    puts "Loaded #{@bands_index.length} bands from index"
  end

  def process
    puts ""
    puts "Processing recordings from: #{@input_path}"
    puts "Output directory: #{@output_dir}"
    puts "Limit: #{@limit || 'none'}"
    puts "Min duration: #{@min_duration}ms"
    puts ""
    
    File.foreach(@input_path).with_index do |line, index|
      break if @limit && @total_processed >= @limit
      
      begin
        recording = JSON.parse(line)
        process_recording(recording, index + 1)
      rescue JSON::ParserError => e
        puts "Warning: Failed to parse line #{index + 1}: #{e.message}"
      end
      
      # Progress indicator
      if (index + 1) % 100_000 == 0
        puts "Processed #{index + 1} lines, #{@total_processed} tracks created, #{@total_skipped} skipped..."
      end
    end
    
    # Write any remaining tracks
    write_batch if @tracks.any?
    
    puts ""
    puts "Complete!"
    puts "Total tracks created: #{@total_processed}"
    puts "Total skipped: #{@total_skipped}"
    puts "  - No matching artist: #{@skipped_no_artist}"
    puts "  - Too short: #{@skipped_too_short}"
    puts "Seed files written: #{@file_counter - 1}"
  end

  private

  def load_bands_index
    # First try the database-generated index (has actual IDs)
    db_index_path = @bands_index_path.sub('.json', '_db_index.json')
    if File.exist?(db_index_path)
      puts "Using database index: #{db_index_path}"
      return JSON.parse(File.read(db_index_path))
    end
    
    # Fall back to the processing-time index
    if File.exist?(@bands_index_path)
      puts "Using processing index: #{@bands_index_path}"
      puts "Warning: This index has placeholder IDs. Run build_bands_index.rb after importing bands."
      return JSON.parse(File.read(@bands_index_path))
    end
    
    puts "Error: Bands index not found at #{@bands_index_path}"
    puts "Run process_artists.rb first to generate the bands index."
    exit 1
  end

  def process_recording(recording, line_number)
    # Skip if no MBID
    mbid = recording['id']
    return skip('no mbid') unless mbid
    
    # Skip if no title
    title = recording['title']
    return skip('no title') unless title && !title.empty?
    
    # Get duration
    duration_ms = recording['length']
    if duration_ms && duration_ms < @min_duration
      @skipped_too_short += 1
      return skip('too short')
    end
    
    # Get the primary artist
    artist_credit = recording['artist-credit']
    return skip_no_artist unless artist_credit&.any?
    
    # Find the first artist with a matching band in our index
    band_id = nil
    artist_credit.each do |credit|
      artist = credit['artist']
      next unless artist && artist['id']
      
      if @bands_index.key?(artist['id'])
        band_id = @bands_index[artist['id']]
        break
      end
    end
    
    return skip_no_artist unless band_id
    
    # Extract ISRCs (International Standard Recording Codes)
    isrcs = recording['isrcs'] || []
    isrc = isrcs.first # Take the first one if multiple exist
    
    # Extract tags/genres
    tags = extract_tags(recording)
    
    # Generate a UUID for the track (matching your schema)
    track_uuid = SecureRandom.uuid
    
    track = {
      id: track_uuid,
      name: title,
      band_id: band_id,
      album_id: nil, # Will need separate linking step - see note below
      duration_ms: duration_ms,
      musicbrainz_recording_id: mbid,
      isrc: isrc,
      genres: tags,
      source: 0, # 0 = musicbrainz, 1 = user_submitted (matches Rails enum)
      verified: false,
      created_at: Time.now.utc.iso8601,
      updated_at: Time.now.utc.iso8601
    }
    
    @tracks << track
    @total_processed += 1
    
    # Write batch if full
    write_batch if @tracks.length >= BATCH_SIZE
  end

  def extract_tags(recording)
    return [] unless recording['tags']
    
    recording['tags']
      .sort_by { |t| -(t['count'] || 0) }
      .take(10)
      .map { |t| t['name'] }
      .compact
  end

  def skip(reason)
    @total_skipped += 1
    nil
  end

  def skip_no_artist
    @total_skipped += 1
    @skipped_no_artist += 1
    nil
  end

  def write_batch
    return if @tracks.empty?
    
    filename = "tracks_#{@file_counter.to_s.rjust(3, '0')}.rb"
    filepath = File.join(@output_dir, filename)
    
    File.open(filepath, 'w') do |f|
      f.puts "# Generated from MusicBrainz data dump"
      f.puts "# Contains #{@tracks.length} track records"
      f.puts "# Generated at: #{Time.now.utc.iso8601}"
      f.puts ""
      f.puts "# NOTE: album_id is nil - recordings need to be linked to albums separately"
      f.puts "# See link_tracks_to_albums.rb for post-processing"
      f.puts ""
      f.puts "# IMPORTANT: Run build_bands_index.rb first if you haven't already"
      f.puts ""
      f.puts "tracks_data = ["
      
      @tracks.each_with_index do |track, index|
        # Convert to proper Ruby hash format
        hash_parts = []
        track.each do |key, value|
          formatted_value = case value
          when String
            # Escape quotes and special characters
            escaped = value.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
            "\"#{escaped}\""
          when Array
            value.inspect
          when nil
            'nil'
          else
            value
          end
          hash_parts << "#{key}: #{formatted_value}"
        end
        
        comma = index < @tracks.length - 1 ? ',' : ''
        f.puts "  { #{hash_parts.join(', ')} }#{comma}"
      end
      
      f.puts "]"
      f.puts ""
      f.puts "puts \"Inserting #{@tracks.length} tracks from #{filename}...\""
      f.puts ""
      f.puts "# Use insert_all for performance, skip duplicates"
      f.puts "Track.insert_all("
      f.puts "  tracks_data,"
      f.puts "  unique_by: :musicbrainz_recording_id,"
      f.puts "  record_timestamps: false"
      f.puts ")"
      f.puts ""
      f.puts "puts \"Done! Total tracks in database: \#{Track.count}\""
    end
    
    puts "Wrote #{filepath} (#{@tracks.length} records)"
    
    @tracks = []
    @file_counter += 1
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby process_recordings.rb [options]"

  opts.on("-i", "--input PATH", "Path to extracted recording JSONL file") do |v|
    options[:input] = v
  end

  opts.on("-o", "--output DIR", "Output directory for seed files") do |v|
    options[:output] = v
  end

  opts.on("-b", "--bands-index PATH", "Path to bands_index.json from process_artists.rb") do |v|
    options[:bands_index] = v
  end

  opts.on("-l", "--limit N", Integer, "Maximum number of recordings to process") do |v|
    options[:limit] = v
  end

  opts.on("-d", "--min-duration MS", Integer, "Minimum track duration in milliseconds (default: 30000)") do |v|
    options[:min_duration] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Validate required options
unless options[:input] && options[:output] && options[:bands_index]
  puts "Error: --input, --output, and --bands-index are required"
  puts "Run with --help for usage"
  exit 1
end

unless File.exist?(options[:input])
  puts "Error: Input file not found: #{options[:input]}"
  exit 1
end

# Run processor
processor = RecordingProcessor.new(options)
processor.process
