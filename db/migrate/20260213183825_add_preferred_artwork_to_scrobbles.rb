class AddPreferredArtworkToScrobbles < ActiveRecord::Migration[8.0]
  def change
    add_column :scrobbles, :preferred_artwork_url, :string
  end
end
