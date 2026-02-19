class AddLastfmFieldsToScrobbles < ActiveRecord::Migration[8.0]
  def change
    # Make duration_ms nullable for Last.fm tracks (they don't provide duration)
    change_column_null :scrobbles, :duration_ms, true

    # Last.fm specific metadata
    add_column :scrobbles, :lastfm_url, :string
    add_column :scrobbles, :lastfm_loved, :boolean, default: false

    # Additional MusicBrainz IDs from Last.fm
    add_column :scrobbles, :artist_mbid, :string
    add_column :scrobbles, :album_mbid, :string

    # Index for finding Last.fm converted scrobbles
    add_index :scrobbles, :source_app, where: "source_app = 'lastfm'"
  end
end
