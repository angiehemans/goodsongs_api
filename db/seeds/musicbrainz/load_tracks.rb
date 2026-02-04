# load_tracks.rb
# Loads track seeds with band_id remapping at runtime
#
# Usage: rails runner "load 'db/seeds/musicbrainz/load_tracks.rb'"

require 'json'

puts "Building band ID mapping..."

seq_index_path = Rails.root.join('db/seeds/musicbrainz/bands_index.json')
seq_index = JSON.parse(File.read(seq_index_path))

seq_to_mbid = seq_index.invert

mbid_to_db_id = {}
Band.where.not(musicbrainz_id: [nil, '']).pluck(:musicbrainz_id, :id).each do |mbid, id|
  mbid_to_db_id[mbid] = id
end

seq_to_db = {}
seq_to_mbid.each do |seq_id_str, mbid|
  db_id = mbid_to_db_id[mbid]
  seq_to_db[seq_id_str.to_i] = db_id if db_id
end

puts "Mapped #{seq_to_db.length} band IDs"

skipped = 0
loaded = 0

Dir[Rails.root.join('db/seeds/musicbrainz/tracks_*.rb')].sort.each do |file|
  filename = File.basename(file)
  puts "Processing #{filename}..."

  content = File.read(file)
  array_match = content.match(/tracks_data\s*=\s*(\[.+?\])\s*$/m)
  unless array_match
    puts "  Skipping #{filename}: could not find tracks_data array"
    next
  end

  # rubocop:disable Security/Eval
  tracks_data = eval(array_match[1])
  # rubocop:enable Security/Eval

  remapped = tracks_data.filter_map do |track|
    new_band_id = seq_to_db[track[:band_id]]
    if new_band_id
      track[:band_id] = new_band_id
      track
    else
      skipped += 1
      nil
    end
  end

  if remapped.any?
    Track.insert_all(
      remapped,
      unique_by: :musicbrainz_recording_id,
      record_timestamps: false
    )
    loaded += remapped.length
    puts "  Inserted #{remapped.length} tracks (#{tracks_data.length - remapped.length} skipped - band not found)"
  else
    puts "  No tracks to insert (all bands missing)"
  end
end

puts ""
puts "Done!"
puts "Tracks loaded: #{loaded}"
puts "Tracks skipped (band not in DB): #{skipped}"
puts "Total tracks in database: #{Track.count}"
