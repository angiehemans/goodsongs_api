class AddAudioDbIdsToBandsAlbumsAndTracks < ActiveRecord::Migration[8.0]
  def change
    # Add TheAudioDB artist ID to bands
    add_column :bands, :audiodb_artist_id, :string
    add_index :bands, :audiodb_artist_id, unique: true, where: "audiodb_artist_id IS NOT NULL"

    # Add TheAudioDB album ID to albums
    add_column :albums, :audiodb_album_id, :string
    add_index :albums, :audiodb_album_id, unique: true, where: "audiodb_album_id IS NOT NULL"

    # Add TheAudioDB track ID to tracks
    add_column :tracks, :audiodb_track_id, :string
    add_index :tracks, :audiodb_track_id, unique: true, where: "audiodb_track_id IS NOT NULL"
  end
end
