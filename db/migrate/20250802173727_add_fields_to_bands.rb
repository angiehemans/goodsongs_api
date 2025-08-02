class AddFieldsToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :location, :string
    add_column :bands, :spotify_link, :string
    add_column :bands, :bandcamp_link, :string
    add_column :bands, :apple_music_link, :string
    add_column :bands, :youtube_music_link, :string
    add_column :bands, :about, :text
  end
end
