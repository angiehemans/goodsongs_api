# frozen_string_literal: true

class AddImageCachingFields < ActiveRecord::Migration[8.0]
  def change
    # Track when images were cached and from which source
    add_column :bands, :artist_image_source, :string
    add_column :bands, :artist_image_cached_at, :datetime

    add_column :albums, :cover_art_source, :string
    add_column :albums, :cover_art_cached_at, :datetime

    # Add indexes for efficient queries when backfilling
    add_index :bands, :artist_image_source, where: "artist_image_source IS NOT NULL"
    add_index :albums, :cover_art_source, where: "cover_art_source IS NOT NULL"
  end
end
