class AddLastfmToUsersAndBands < ActiveRecord::Migration[8.0]
  def change
    # Add Last.fm username to users
    add_column :users, :lastfm_username, :string
    add_index :users, :lastfm_username

    # Add Last.fm fields to bands
    add_column :bands, :lastfm_artist_name, :string
    add_column :bands, :lastfm_image_url, :string

    # Rename spotify_image_url to artist_image_url for generic use
    # This column will store the image URL from whichever service is used
    rename_column :bands, :spotify_image_url, :artist_image_url
  end
end
