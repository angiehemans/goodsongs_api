class AddAndroidMetadataToScrobbles < ActiveRecord::Migration[8.0]
  def change
    add_column :scrobbles, :album_artist, :string
    add_column :scrobbles, :genre, :string
    add_column :scrobbles, :year, :integer
    add_column :scrobbles, :release_date, :date
    add_column :scrobbles, :artwork_uri, :string

    add_index :scrobbles, :genre, where: "genre IS NOT NULL"
  end
end
