#!/usr/bin/env ruby
# frozen_string_literal: true

# inspect_dump.rb
# Analyzes MusicBrainz JSON dump files to understand their structure
# Run this before processing to verify the dump format

require 'json'
require 'optparse'

class DumpInspector
  def initialize(input_path, sample_size = 5)
    @input_path = input_path
    @sample_size = sample_size
  end

  def inspect
    puts "=" * 60
    puts "Inspecting: #{@input_path}"
    puts "=" * 60
    puts ""
    
    unless File.exist?(@input_path)
      puts "ERROR: File not found!"
      return
    end
    
    file_size = File.size(@input_path)
    puts "File size: #{format_size(file_size)}"
    puts ""
    
    # Count lines and analyze structure
    sample_records = []
    line_count = 0
    
    File.foreach(@input_path) do |line|
      line_count += 1
      
      if sample_records.length < @sample_size
        begin
          record = JSON.parse(line)
          sample_records << record
        rescue JSON::ParserError => e
          puts "Warning: Line #{line_count} is not valid JSON: #{e.message}"
        end
      end
      
      # Quick count (stop after 1M lines for estimation)
      break if line_count >= 1_000_000
    end
    
    if line_count >= 1_000_000
      # Estimate total lines based on file position
      estimated_total = (file_size.to_f / (File.new(@input_path).pos.to_f / line_count)).to_i
      puts "Estimated total records: ~#{estimated_total.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    else
      puts "Total records: #{line_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end
    puts ""
    
    if sample_records.empty?
      puts "ERROR: Could not parse any records!"
      return
    end
    
    # Analyze structure
    puts "Sample Record Structure"
    puts "-" * 40
    
    all_keys = sample_records.flat_map(&:keys).uniq.sort
    
    puts "Available fields:"
    all_keys.each do |key|
      values = sample_records.map { |r| r[key] }.compact
      if values.any?
        sample_value = values.first
        type = case sample_value
               when String then "string"
               when Integer then "integer"
               when Float then "float"
               when Array then "array[#{sample_value.first&.class || 'empty'}]"
               when Hash then "object"
               when TrueClass, FalseClass then "boolean"
               when NilClass then "null"
               else sample_value.class.to_s
               end
        presence = "#{values.length}/#{sample_records.length}"
        puts "  #{key.ljust(30)} #{type.ljust(20)} (#{presence} samples)"
      end
    end
    
    puts ""
    puts "Sample Records"
    puts "-" * 40
    
    sample_records.take(3).each_with_index do |record, i|
      puts ""
      puts "Record #{i + 1}:"
      puts JSON.pretty_generate(record).lines.take(30).join
      puts "..." if JSON.pretty_generate(record).lines.length > 30
    end
    
    puts ""
    puts "=" * 60
    puts "Key Fields for GoodSongs:"
    puts "=" * 60
    
    # Provide guidance based on file type
    filename = File.basename(@input_path)
    
    case filename
    when /artist/i
      puts "For bands table, map:"
      puts "  id          -> musicbrainz_id"
      puts "  name        -> name"
      puts "  sort-name   -> sort_name"
      puts "  type        -> artist_type"
      puts "  country     -> country"
      puts "  area        -> (extract country from)"
      puts "  tags        -> genres (array)"
      puts "  aliases     -> aliases (array)"
    when /release-group/i
      puts "For albums table, map:"
      puts "  id           -> musicbrainz_release_id"
      puts "  title        -> name"
      puts "  primary-type -> release_type"
      puts "  first-release-date -> release_date"
      puts "  artist-credit -> (lookup band_id)"
      puts "  tags         -> genres (array)"
    when /recording/i
      puts "For tracks table, map:"
      puts "  id           -> musicbrainz_recording_id"
      puts "  title        -> name"
      puts "  length       -> duration_ms"
      puts "  isrcs        -> isrc (first one)"
      puts "  artist-credit -> (lookup band_id)"
      puts "  tags         -> genres (array)"
    end
  end

  private

  def format_size(bytes)
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    unit_index = 0
    size = bytes.to_f
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(2)} #{units[unit_index]}"
  end
end

# Parse command line options
options = { sample_size: 5 }

OptionParser.new do |opts|
  opts.banner = "Usage: ruby inspect_dump.rb [options] <path_to_dump_file>"

  opts.on("-s", "--samples N", Integer, "Number of sample records to analyze (default: 5)") do |v|
    options[:sample_size] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

if ARGV.empty?
  puts "Error: Please provide a path to a dump file"
  puts "Usage: ruby inspect_dump.rb path/to/artist"
  exit 1
end

inspector = DumpInspector.new(ARGV[0], options[:sample_size])
inspector.inspect
