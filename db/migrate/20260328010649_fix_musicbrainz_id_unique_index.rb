class FixMusicbrainzIdUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    # Clean up empty strings to NULL first
    Band.where(musicbrainz_id: '').update_all(musicbrainz_id: nil)

    # Replace the unconditional unique index with a partial one (matching audiodb/discogs pattern)
    remove_index :bands, :musicbrainz_id
    add_index :bands, :musicbrainz_id, unique: true, where: "(musicbrainz_id IS NOT NULL)"
  end

  def down
    remove_index :bands, :musicbrainz_id
    add_index :bands, :musicbrainz_id, unique: true
  end
end
