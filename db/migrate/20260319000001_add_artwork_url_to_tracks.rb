class AddArtworkUrlToTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :tracks, :artwork_url, :string
  end
end
