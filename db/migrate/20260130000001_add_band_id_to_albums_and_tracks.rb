# frozen_string_literal: true

class AddBandIdToAlbumsAndTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :albums, :band_id, :bigint
    add_index :albums, :band_id

    add_column :tracks, :band_id, :bigint
    add_index :tracks, :band_id
  end
end
