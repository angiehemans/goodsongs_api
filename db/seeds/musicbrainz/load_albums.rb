# load_albums.rb
# Loads album seeds with band_id remapping at runtime
#
# The album seed files reference band_id as a sequential processing ID.
# This script builds a mapping from those IDs to actual DB IDs using
# bands_index.json (musicbrainz_id -> sequential ID) and the live database.
#
# Usage: rails runner "load 'db/seeds/musicbrainz/load_albums.rb'"

require 'json'

puts "Building band ID mapping..."

# bands_index.json maps musicbrainz_id -> sequential processing ID
seq_index_path = Rails.root.join('db/seeds/musicbrainz/bands_index.json')
seq_index = JSON.parse(File.read(seq_index_path))

# Build reverse map: sequential ID -> musicbrainz_id
seq_to_mbid = seq_index.invert

# Build musicbrainz_id -> actual DB ID from live database
mbid_to_db_id = {}
Band.where.not(musicbrainz_id: [nil, '']).pluck(:musicbrainz_id, :id).each do |mbid, id|
  mbid_to_db_id[mbid] = id
end

# Final map: sequential processing ID -> actual DB ID
seq_to_db = {}
seq_to_mbid.each do |seq_id_str, mbid|
  db_id = mbid_to_db_id[mbid]
  seq_to_db[seq_id_str.to_i] = db_id if db_id
end

puts "Mapped #{seq_to_db.length} band IDs"

# Load each album seed file
skipped = 0
loaded = 0

Dir[Rails.root.join('db/seeds/musicbrainz/albums_*.rb')].sort.each do |file|
  filename = File.basename(file)
  puts "Processing #{filename}..."

  # Read and eval just the data array (not the insert_all call)
  content = File.read(file)
  array_match = content.match(/albums_data\s*=\s*(\[.+?\])\s*$/m)
  unless array_match
    puts "  Skipping #{filename}: could not find albums_data array"
    next
  end

  # rubocop:disable Security/Eval
  albums_data = eval(array_match[1])
  # rubocop:enable Security/Eval

  # Remap band_ids
  remapped = albums_data.filter_map do |album|
    new_band_id = seq_to_db[album[:band_id]]
    if new_band_id
      album[:band_id] = new_band_id
      album
    else
      skipped += 1
      nil
    end
  end

  if remapped.any?
    Album.insert_all(
      remapped,
      unique_by: :musicbrainz_release_id,
      record_timestamps: false
    )
    loaded += remapped.length
    puts "  Inserted #{remapped.length} albums (#{albums_data.length - remapped.length} skipped - band not found)"
  else
    puts "  No albums to insert (all bands missing)"
  end
end

puts ""
puts "Done!"
puts "Albums loaded: #{loaded}"
puts "Albums skipped (band not in DB): #{skipped}"
puts "Total albums in database: #{Album.count}"
