#!/usr/bin/env ruby
# frozen_string_literal: true

# process_release_groups.rb
# Processes MusicBrainz release-group JSON dump and generates Rails seed files for albums table

require 'json'
require 'optparse'
require 'fileutils'
require 'securerandom'
require 'time'

class ReleaseGroupProcessor
  BATCH_SIZE = 10_000
  
  # MusicBrainz release type mappings
  TYPE_MAP = {
    'Album' => 'album',
    'Single' => 'single',
    'EP' => 'ep',
    'Broadcast' => 'broadcast',
    'Other' => 'other',
    'Compilation' => 'compilation',
    'Soundtrack' => 'soundtrack',
    'Spokenword' => 'spokenword',
    'Interview' => 'interview',
    'Audiobook' => 'audiobook',
    'Audio drama' => 'audio_drama',
    'Live' => 'live',
    'Remix' => 'remix',
    'DJ-mix' => 'dj_mix',
    'Mixtape/Street' => 'mixtape',
    'Demo' => 'demo'
  }.freeze

  def initialize(options)
    @input_path = options[:input]
    @output_dir = options[:output]
    @bands_index_path = options[:bands_index]
    @limit = options[:limit]
    @allowed_types = options[:types]&.split(',')&.map(&:strip)
    
    @albums = []
    @albums_index = {}
    @file_counter = 1
    @total_processed = 0
    @total_skipped = 0
    @skipped_no_artist = 0
    
    FileUtils.mkdir_p(@output_dir)
    
    # Load bands index to look up band IDs
    @bands_index = load_bands_index
    puts "Loaded #{@bands_index.length} bands from index"
  end

  def process
    puts ""
    puts "Processing release groups from: #{@input_path}"
    puts "Output directory: #{@output_dir}"
    puts "Limit: #{@limit || 'none'}"
    puts ""
    
    File.foreach(@input_path).with_index do |line, index|
      break if @limit && @total_processed >= @limit
      
      begin
        release_group = JSON.parse(line)
        process_release_group(release_group, index + 1)
      rescue JSON::ParserError => e
        puts "Warning: Failed to parse line #{index + 1}: #{e.message}"
      end
      
      # Progress indicator
      if (index + 1) % 100_000 == 0
        puts "Processed #{index + 1} lines, #{@total_processed} albums created, #{@total_skipped} skipped (#{@skipped_no_artist} no matching artist)..."
      end
    end
    
    # Write any remaining albums
    write_batch if @albums.any?
    
    # Write the index file
    write_index
    
    puts ""
    puts "Complete!"
    puts "Total albums created: #{@total_processed}"
    puts "Total skipped: #{@total_skipped}"
    puts "  - No matching artist: #{@skipped_no_artist}"
    puts "Seed files written: #{@file_counter - 1}"
    puts "Index file: #{File.join(@output_dir, 'albums_index.json')}"
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

  def process_release_group(rg, line_number)
    # Skip if no MBID
    mbid = rg['id']
    return skip('no mbid') unless mbid
    
    # Skip if no title
    title = rg['title']
    return skip('no title') unless title && !title.empty?
    
    # Get the primary artist
    artist_credit = rg['artist-credit']
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
    
    # Extract type
    primary_type = rg['primary-type']
    secondary_types = rg['secondary-types'] || []
    
    # Determine the release type
    release_type = determine_release_type(primary_type, secondary_types)
    
    # Filter by type if specified
    if @allowed_types
      return skip('type filtered') unless @allowed_types.include?(release_type)
    end
    
    # Extract tags/genres
    tags = extract_tags(rg)
    
    # Extract release date (first-release-date)
    release_date = parse_release_date(rg['first-release-date'])
    
    # Generate a UUID for the album (matching your schema)
    album_uuid = SecureRandom.uuid
    
    album = {
      id: album_uuid,
      name: title,
      band_id: band_id,
      musicbrainz_release_id: mbid,
      release_date: release_date,
      release_type: release_type,
      genres: tags,
      source: 0, # 0 = musicbrainz, 1 = user_submitted (matches Rails enum)
      verified: false,
      created_at: Time.now.utc.iso8601,
      updated_at: Time.now.utc.iso8601
    }
    
    @albums << album
    @albums_index[mbid] = album_uuid
    @total_processed += 1
    
    # Write batch if full
    write_batch if @albums.length >= BATCH_SIZE
  end

  def determine_release_type(primary, secondary)
    # Use secondary type if it's more specific
    if secondary.any?
      mapped = secondary.map { |t| TYPE_MAP[t] }.compact.first
      return mapped if mapped
    end
    
    TYPE_MAP[primary] || primary&.downcase || 'album'
  end

  def extract_tags(rg)
    return [] unless rg['tags']
    
    rg['tags']
      .sort_by { |t| -(t['count'] || 0) }
      .take(10)
      .map { |t| t['name'] }
      .compact
  end

  def parse_release_date(date_str)
    return nil unless date_str
    
    # MusicBrainz dates can be partial: "2023", "2023-05", "2023-05-15"
    case date_str.length
    when 4
      "#{date_str}-01-01"
    when 7
      "#{date_str}-01"
    when 10
      date_str
    else
      nil
    end
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
    return if @albums.empty?
    
    filename = "albums_#{@file_counter.to_s.rjust(3, '0')}.rb"
    filepath = File.join(@output_dir, filename)
    
    File.open(filepath, 'w') do |f|
      f.puts "# Generated from MusicBrainz data dump"
      f.puts "# Contains #{@albums.length} album records"
      f.puts "# Generated at: #{Time.now.utc.iso8601}"
      f.puts ""
      f.puts "# IMPORTANT: Run build_bands_index.rb first if you haven't already"
      f.puts "# This ensures band_id references are correct"
      f.puts ""
      f.puts "albums_data = ["
      
      @albums.each_with_index do |album, index|
        # Convert to proper Ruby hash format
        hash_parts = []
        album.each do |key, value|
          formatted_value = case value
          when String
            value.include?('"') ? "'#{value.gsub("'", "\\\\'")}'" : "\"#{value}\""
          when Array
            value.inspect
          when nil
            'nil'
          else
            value
          end
          hash_parts << "#{key}: #{formatted_value}"
        end
        
        comma = index < @albums.length - 1 ? ',' : ''
        f.puts "  { #{hash_parts.join(', ')} }#{comma}"
      end
      
      f.puts "]"
      f.puts ""
      f.puts "puts \"Inserting #{@albums.length} albums from #{filename}...\""
      f.puts ""
      f.puts "# Use insert_all for performance, skip duplicates"
      f.puts "Album.insert_all("
      f.puts "  albums_data,"
      f.puts "  unique_by: :musicbrainz_release_id,"
      f.puts "  record_timestamps: false"
      f.puts ")"
      f.puts ""
      f.puts "puts \"Done! Total albums in database: \#{Album.count}\""
    end
    
    puts "Wrote #{filepath} (#{@albums.length} records)"
    
    @albums = []
    @file_counter += 1
  end

  def write_index
    index_path = File.join(@output_dir, 'albums_index.json')
    File.write(index_path, JSON.pretty_generate(@albums_index))
    puts "Wrote index: #{index_path}"
    
    # Also write a helper that can rebuild the index from the database
    helper_path = File.join(@output_dir, 'build_albums_index.rb')
    File.open(helper_path, 'w') do |f|
      f.puts "# Helper script to build albums index from database"
      f.puts "# Run after importing albums: rails runner db/seeds/musicbrainz/build_albums_index.rb"
      f.puts ""
      f.puts "require 'json'"
      f.puts ""
      f.puts "puts 'Building albums index from database...'"
      f.puts ""
      f.puts "index = {}"
      f.puts "Album.where.not(musicbrainz_release_id: nil).find_each do |album|"
      f.puts "  index[album.musicbrainz_release_id] = album.id"
      f.puts "end"
      f.puts ""
      f.puts "File.write('db/seeds/musicbrainz/albums_db_index.json', JSON.pretty_generate(index))"
      f.puts "puts \"Wrote albums_db_index.json with \#{index.length} entries\""
    end
    puts "Wrote helper: #{helper_path}"
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby process_release_groups.rb [options]"

  opts.on("-i", "--input PATH", "Path to extracted release-group JSONL file") do |v|
    options[:input] = v
  end

  opts.on("-o", "--output DIR", "Output directory for seed files") do |v|
    options[:output] = v
  end

  opts.on("-b", "--bands-index PATH", "Path to bands_index.json from process_artists.rb") do |v|
    options[:bands_index] = v
  end

  opts.on("-l", "--limit N", Integer, "Maximum number of release groups to process") do |v|
    options[:limit] = v
  end

  opts.on("-t", "--types LIST", "Comma-separated list of release types to include (album,ep,single)") do |v|
    options[:types] = v
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
processor = ReleaseGroupProcessor.new(options)
processor.process
