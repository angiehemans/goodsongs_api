class AddSongToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :song_name, :string
    add_column :posts, :band_name, :string
    add_column :posts, :album_name, :string
    add_column :posts, :artwork_url, :string
    add_column :posts, :song_link, :string
    add_reference :posts, :track, type: :uuid, foreign_key: true, index: true
  end
end
