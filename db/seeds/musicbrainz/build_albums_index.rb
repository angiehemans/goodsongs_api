# Helper script to build albums index from database
# Run after importing albums: rails runner db/seeds/musicbrainz/build_albums_index.rb

require 'json'

puts 'Building albums index from database...'

index = {}
Album.where.not(musicbrainz_release_id: nil).find_each do |album|
  index[album.musicbrainz_release_id] = album.id
end

File.write('db/seeds/musicbrainz/albums_db_index.json', JSON.pretty_generate(index))
puts "Wrote albums_db_index.json with #{index.length} entries"
