# Helper script to build bands index from database
# Run after importing bands: rails runner db/seeds/musicbrainz/build_bands_index.rb

require 'json'

puts 'Building bands index from database...'

index = {}
Band.where.not(musicbrainz_id: nil).find_each do |band|
  index[band.musicbrainz_id] = band.id
end

File.write('db/seeds/musicbrainz/bands_db_index.json', JSON.pretty_generate(index))
puts "Wrote bands_db_index.json with #{index.length} entries"
