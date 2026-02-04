#!/usr/bin/env ruby
# frozen_string_literal: true

# process_artists.rb
# Processes MusicBrainz artist JSON dump and generates Rails seed files for bands table

require 'json'
require 'optparse'
require 'fileutils'
require 'time'

class ArtistProcessor
  BATCH_SIZE = 10_000
  
  # MusicBrainz type mappings
  TYPE_MAP = {
    'Person' => 'person',
    'Group' => 'group',
    'Orchestra' => 'orchestra',
    'Choir' => 'choir',
    'Character' => 'character',
    'Other' => 'other'
  }.freeze

  def initialize(options)
    @input_path = options[:input]
    @output_dir = options[:output]
    @limit = options[:limit]
    @min_tags = options[:min_tags] || 0
    @allowed_types = options[:types]&.split(',')&.map(&:strip)
    @allowed_genres = options[:genres]&.split(',')&.map(&:strip)&.map(&:downcase)
    @allowed_countries = options[:countries]&.split(',')&.map(&:strip)

    @bands = []
    @bands_index = {}
    @used_slugs = Set.new
    @file_counter = 1
    @total_processed = 0
    @total_skipped = 0

    FileUtils.mkdir_p(@output_dir)
  end

  def process
    puts "Processing artists from: #{@input_path}"
    puts "Output directory: #{@output_dir}"
    puts "Limit: #{@limit || 'none'}"
    puts "Min tags: #{@min_tags}"
    puts ""
    
    File.foreach(@input_path).with_index do |line, index|
      break if @limit && @total_processed >= @limit
      
      begin
        artist = JSON.parse(line)
        process_artist(artist, index + 1)
      rescue JSON::ParserError => e
        puts "Warning: Failed to parse line #{index + 1}: #{e.message}"
      end
      
      # Progress indicator
      if (index + 1) % 100_000 == 0
        puts "Processed #{index + 1} lines, #{@total_processed} bands created, #{@total_skipped} skipped..."
      end
    end
    
    # Write any remaining bands
    write_batch if @bands.any?
    
    # Write the index file (maps musicbrainz_id -> sequential ID for relationships)
    write_index
    
    puts ""
    puts "Complete!"
    puts "Total bands created: #{@total_processed}"
    puts "Total skipped: #{@total_skipped}"
    puts "Seed files written: #{@file_counter - 1}"
    puts "Index file: #{File.join(@output_dir, 'bands_index.json')}"
  end

  private

  def process_artist(artist, line_number)
    # Skip if no MBID
    mbid = artist['id']
    return skip('no mbid') unless mbid
    
    # Skip if no name
    name = artist['name']
    return skip('no name') unless name && !name.empty?
    
    # Extract type
    artist_type = artist['type']
    
    # Filter by type if specified
    if @allowed_types && artist_type
      return skip('type filtered') unless @allowed_types.include?(artist_type)
    end
    
    # Extract tags/genres
    tags = extract_tags(artist)
    
    # Filter by minimum tags
    return skip('not enough tags') if tags.length < @min_tags
    
    # Filter by genre if specified
    if @allowed_genres
      tag_names = tags.map { |t| t.downcase }
      return skip('genre filtered') unless (@allowed_genres & tag_names).any?
    end
    
    # Extract area/country info
    area = artist['area'] || {}
    country = extract_country(artist, area)

    # Filter by country if specified
    if @allowed_countries
      return skip('country filtered') unless country && @allowed_countries.include?(country)
    end

    # Extract city from begin-area
    city = extract_city(artist)

    # Extract region from area (when area is not a country)
    region = extract_region(area)

    # Generate unique slug
    slug = generate_unique_slug(name)

    # Extract aliases
    aliases = extract_aliases(artist)

    # Build band record
    # Note: We're using a sequential ID here that we'll track in the index
    # Rails will generate the actual ID, but we need predictable IDs for relationships
    band_id = @total_processed + 1

    band = {
      name: name,
      sort_name: artist['sort-name'] || name,
      musicbrainz_id: mbid,
      artist_type: TYPE_MAP[artist_type] || artist_type&.downcase,
      country: country,
      city: city,
      region: region,
      slug: slug,
      aliases: aliases,
      genres: tags,
      source: 0, # 0 = musicbrainz, 1 = user_submitted (matches Rails enum)
      verified: false,
      created_at: Time.now.utc.iso8601,
      updated_at: Time.now.utc.iso8601
    }
    
    @bands << band
    @bands_index[mbid] = band_id
    @total_processed += 1
    
    # Write batch if full
    write_batch if @bands.length >= BATCH_SIZE
  end

  def extract_tags(artist)
    return [] unless artist['tags']
    
    # Tags come with counts - sort by count and take top ones
    artist['tags']
      .sort_by { |t| -(t['count'] || 0) }
      .take(10)
      .map { |t| t['name'] }
      .compact
  end

  def extract_city(artist)
    begin_area = artist['begin-area']
    return nil unless begin_area && begin_area['name'] && !begin_area['name'].empty?

    begin_area['name']
  end

  def extract_region(area)
    return nil unless area && area['name'] && !area['name'].empty?

    # If the area has ISO 3166-1 codes, it's a country — not a region
    return nil if area['iso-3166-1-codes']&.any?

    area['name']
  end

  def generate_unique_slug(name)
    base_slug = name.downcase.gsub(/[^a-z0-9\-_]/, '-').gsub(/-+/, '-').gsub(/^-+|-+$/, '')
    base_slug = 'band' if base_slug.empty?

    slug = base_slug
    counter = 2
    while @used_slugs.include?(slug)
      slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    @used_slugs.add(slug)
    slug
  end

  def extract_country(artist, area)
    # Try to get ISO country code
    if artist['country']
      return artist['country']
    end
    
    # Fall back to area info
    if area['iso-3166-1-codes']&.any?
      return area['iso-3166-1-codes'].first
    end
    
    nil
  end

  def extract_aliases(artist)
    return [] unless artist['aliases']
    
    artist['aliases']
      .select { |a| a['name'] && a['name'] != artist['name'] }
      .map { |a| { name: a['name'], locale: a['locale'] } }
      .uniq { |a| a[:name] }
      .take(10)
  end

  def skip(reason)
    @total_skipped += 1
    nil
  end

  def write_batch
    return if @bands.empty?
    
    filename = "bands_#{@file_counter.to_s.rjust(3, '0')}.rb"
    filepath = File.join(@output_dir, filename)
    
    File.open(filepath, 'w') do |f|
      country_note = @allowed_countries ? " (filtered: #{@allowed_countries.join(', ')})" : ""
      f.puts "# Generated from MusicBrainz data dump#{country_note}"
      f.puts "# Contains #{@bands.length} band records"
      f.puts "# Generated at: #{Time.now.utc.iso8601}"
      f.puts ""
      f.puts "bands_data = ["
      
      @bands.each_with_index do |band, index|
        json = JSON.generate(band)
        # Convert JSON to Ruby hash syntax for cleaner seed files
        ruby_hash = json.gsub(/"(\w+)":/) { "#{$1}: " }
        # Fix JSON null to Ruby nil
        ruby_hash = ruby_hash.gsub(': null', ': nil')
        comma = index < @bands.length - 1 ? ',' : ''
        f.puts "  #{ruby_hash}#{comma}"
      end
      
      f.puts "]"
      f.puts ""
      f.puts "puts \"Inserting #{@bands.length} bands from #{filename}...\""
      f.puts ""
      f.puts "# Resolve slug conflicts with existing bands before upserting"
      f.puts "# Build map of slug -> musicbrainz_id for bands that own each slug"
      f.puts "existing_slugs = {}"
      f.puts "Band.pluck(:slug, :musicbrainz_id).each do |s, m|"
      f.puts "  existing_slugs[s] = m if s.present?"
      f.puts "end"
      f.puts "bands_data.each do |band|"
      f.puts "  slug = band[:slug]"
      f.puts "  owner_mbid = existing_slugs[slug]"
      f.puts "  # Conflict if slug is taken by a different band (different mbid or band has no mbid)"
      f.puts "  if owner_mbid && owner_mbid != band[:musicbrainz_id]"
      f.puts "    counter = 2"
      f.puts "    base = slug"
      f.puts "    while existing_slugs[\"\#{base}-\#{counter}\"]"
      f.puts "      counter += 1"
      f.puts "    end"
      f.puts "    band[:slug] = \"\#{base}-\#{counter}\""
      f.puts "  elsif existing_slugs.key?(slug) && owner_mbid.nil?"
      f.puts "    # Slug taken by a band with no musicbrainz_id — must avoid it"
      f.puts "    counter = 2"
      f.puts "    base = slug"
      f.puts "    while existing_slugs[\"\#{base}-\#{counter}\"]"
      f.puts "      counter += 1"
      f.puts "    end"
      f.puts "    band[:slug] = \"\#{base}-\#{counter}\""
      f.puts "  end"
      f.puts "  existing_slugs[band[:slug]] = band[:musicbrainz_id]"
      f.puts "end"
      f.puts ""
      f.puts "# Use upsert_all to insert new records or update existing ones"
      f.puts "Band.upsert_all("
      f.puts "  bands_data,"
      f.puts "  unique_by: :musicbrainz_id,"
      f.puts "  record_timestamps: false"
      f.puts ")"
      f.puts ""
      f.puts "puts \"Done! Total bands in database: \#{Band.count}\""
    end
    
    puts "Wrote #{filepath} (#{@bands.length} records)"
    
    @bands = []
    @file_counter += 1
  end

  def write_index
    index_path = File.join(@output_dir, 'bands_index.json')
    
    # The index maps musicbrainz_id -> a predictable identifier
    # Since we're using insert_all, we can't know the actual DB IDs ahead of time
    # Instead, we'll generate a lookup seed file that builds the index at runtime
    
    File.write(index_path, JSON.pretty_generate(@bands_index))
    puts "Wrote index: #{index_path}"
    
    # Also write a helper that can rebuild the index from the database
    helper_path = File.join(@output_dir, 'build_bands_index.rb')
    File.open(helper_path, 'w') do |f|
      f.puts "# Helper script to build bands index from database"
      f.puts "# Run after importing bands: rails runner db/seeds/musicbrainz/build_bands_index.rb"
      f.puts ""
      f.puts "require 'json'"
      f.puts ""
      f.puts "puts 'Building bands index from database...'"
      f.puts ""
      f.puts "index = {}"
      f.puts "Band.where.not(musicbrainz_id: nil).find_each do |band|"
      f.puts "  index[band.musicbrainz_id] = band.id"
      f.puts "end"
      f.puts ""
      f.puts "File.write('db/seeds/musicbrainz/bands_db_index.json', JSON.pretty_generate(index))"
      f.puts "puts \"Wrote bands_db_index.json with \#{index.length} entries\""
    end
    puts "Wrote helper: #{helper_path}"
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby process_artists.rb [options]"

  opts.on("-i", "--input PATH", "Path to extracted artist JSONL file") do |v|
    options[:input] = v
  end

  opts.on("-o", "--output DIR", "Output directory for seed files") do |v|
    options[:output] = v
  end

  opts.on("-l", "--limit N", Integer, "Maximum number of artists to process") do |v|
    options[:limit] = v
  end

  opts.on("-m", "--min-tags N", Integer, "Minimum number of genre tags required") do |v|
    options[:min_tags] = v
  end

  opts.on("-t", "--types LIST", "Comma-separated list of artist types to include") do |v|
    options[:types] = v
  end

  opts.on("-g", "--genres LIST", "Comma-separated list of genres to include") do |v|
    options[:genres] = v
  end

  opts.on("-c", "--countries LIST", "Comma-separated list of ISO country codes to include (e.g., US,CA,GB)") do |v|
    options[:countries] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Validate required options
unless options[:input] && options[:output]
  puts "Error: --input and --output are required"
  puts "Run with --help for usage"
  exit 1
end

unless File.exist?(options[:input])
  puts "Error: Input file not found: #{options[:input]}"
  exit 1
end

# Run processor
processor = ArtistProcessor.new(options)
processor.process
