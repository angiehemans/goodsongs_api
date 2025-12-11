class AddSpotifyImageUrlToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :spotify_image_url, :string
  end
end
