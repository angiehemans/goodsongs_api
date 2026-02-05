#!/usr/bin/env ruby
# frozen_string_literal: true

# extract_recording_release_map.rb
# Streams through MusicBrainz release JSON dump and extracts
# recording_id -> release_group_id mappings.
#
# Input: release JSONL (one JSON object per line) via stdin or file
# Output: JSON file mapping recording_mbid -> release_group_mbid
#
# Usage:
#   # From extracted file:
#   ruby extract_recording_release_map.rb -i data/extracted/mbdump/release -o data/seeds/recording_release_map.json
#
#   # Stream from archive without extracting (saves disk):
#   tar -xf data/downloads/release.tar.xz --to-stdout mbdump/release | ruby extract_recording_release_map.rb -o data/seeds/recording_release_map.json

require 'json'
require 'optparse'
require 'set'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby extract_recording_release_map.rb [options]"

  opts.on("-i", "--input PATH", "Path to release JSONL file (reads stdin if omitted)") do |v|
    options[:input] = v
  end

  opts.on("-o", "--output PATH", "Output JSON file path (required)") do |v|
    options[:output] = v
  end

  opts.on("-r", "--recordings PATH", "Optional: only include recordings in this file (one mbid per line)") do |v|
    options[:recordings] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

unless options[:output]
  puts "Error: --output is required"
  exit 1
end

# Optionally filter to only recordings we care about
target_recordings = nil
if options[:recordings]
  target_recordings = Set.new(File.readlines(options[:recordings]).map(&:strip).reject(&:empty?))
  puts "Filtering to #{target_recordings.length} target recordings"
end

# recording_mbid -> release_group_mbid
# We prefer album/ep types over singles/compilations
TYPE_PRIORITY = {
  'Album' => 0,
  'EP' => 1,
  'Single' => 2,
  'Broadcast' => 3,
  'Other' => 4,
  'Compilation' => 5,
  'Soundtrack' => 5,
  'Live' => 6,
  'Remix' => 7,
  'DJ-mix' => 8
}.freeze

mapping = {}       # recording_mbid -> { rg_id:, priority: }
total_lines = 0
total_mappings = 0

input = options[:input] ? File.open(options[:input]) : $stdin

puts "Processing releases..."

input.each_line do |line|
  total_lines += 1

  if total_lines % 500_000 == 0
    puts "  #{total_lines} releases processed, #{mapping.length} unique recordings mapped..."
  end

  begin
    release = JSON.parse(line)
  rescue JSON::ParserError
    next
  end

  rg = release['release-group']
  next unless rg && rg['id']

  rg_id = rg['id']
  rg_type = rg['primary-type'] || 'Other'
  priority = TYPE_PRIORITY[rg_type] || 9

  media = release['media']
  next unless media

  media.each do |medium|
    tracks = medium['tracks']
    next unless tracks

    tracks.each do |track|
      recording = track['recording']
      next unless recording && recording['id']

      rec_id = recording['id']

      # Skip if filtering and not in target set
      next if target_recordings && !target_recordings.include?(rec_id)

      # Keep the best (lowest priority) release group for each recording
      existing = mapping[rec_id]
      if existing.nil? || priority < existing[:priority]
        mapping[rec_id] = { rg_id: rg_id, priority: priority }
        total_mappings += 1
      end
    end
  end
end

input.close if options[:input]

# Write output as simple recording_id -> release_group_id map
output = mapping.transform_values { |v| v[:rg_id] }

File.write(options[:output], JSON.generate(output))

puts ""
puts "Done!"
puts "Releases processed: #{total_lines}"
puts "Unique recordings mapped: #{output.length}"
puts "Output: #{options[:output]}"
