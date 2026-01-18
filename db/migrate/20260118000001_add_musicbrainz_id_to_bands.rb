class AddMusicbrainzIdToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :musicbrainz_id, :string
    add_index :bands, :musicbrainz_id, unique: true
  end
end
