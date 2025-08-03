class AddSpotifyTokensToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :spotify_access_token, :text
    add_column :users, :spotify_refresh_token, :text
    add_column :users, :spotify_expires_at, :datetime
  end
end