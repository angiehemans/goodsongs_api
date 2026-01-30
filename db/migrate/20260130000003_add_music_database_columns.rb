# frozen_string_literal: true

class AddMusicDatabaseColumns < ActiveRecord::Migration[8.0]
  def change
    # 1. Enable pg_trgm extension for trigram similarity search
    enable_extension "pg_trgm"

    # 2. Extend bands table
    change_table :bands, bulk: true do |t|
      t.integer :source, default: 0, null: false
      t.string :discogs_artist_id
      t.string :country
      t.string :artist_type
      t.string :sort_name
      t.jsonb :aliases, default: []
      t.jsonb :genres, default: []
      t.boolean :verified, default: false, null: false
      t.bigint :submitted_by_id
    end
    add_foreign_key :bands, :users, column: :submitted_by_id
    add_index :bands, :submitted_by_id

    # 3. Extend albums table
    change_table :albums, bulk: true do |t|
      t.integer :source, default: 0, null: false
      t.string :discogs_master_id
      t.string :release_type
      t.jsonb :genres, default: []
      t.string :label
      t.string :country
      t.integer :track_count
      t.boolean :verified, default: false, null: false
      t.bigint :submitted_by_id
    end
    add_foreign_key :albums, :users, column: :submitted_by_id
    add_index :albums, :submitted_by_id
    add_index :albums, :discogs_master_id, unique: true

    # 4. Extend tracks table
    change_table :tracks, bulk: true do |t|
      t.integer :source, default: 0, null: false
      t.string :discogs_track_id
      t.integer :track_number
      t.integer :disc_number, default: 1
      t.jsonb :genres, default: []
      t.boolean :verified, default: false, null: false
      t.bigint :submitted_by_id
    end
    add_foreign_key :tracks, :users, column: :submitted_by_id
    add_index :tracks, :submitted_by_id

    # 5. Create band_aliases table
    create_table :band_aliases, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.bigint :band_id, null: false
      t.string :name, null: false
      t.string :locale
      t.datetime :created_at, null: false
    end
    add_foreign_key :band_aliases, :bands, on_delete: :cascade
    add_index :band_aliases, :band_id

    # 6. GIN trigram indexes for fuzzy search
    add_index :bands, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_bands_on_name_trgm"
    add_index :albums, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_albums_on_name_trgm"
    add_index :tracks, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_tracks_on_name_trgm"
    add_index :band_aliases, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_band_aliases_on_name_trgm"
  end
end
