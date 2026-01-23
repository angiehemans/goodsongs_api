# frozen_string_literal: true

class CreateScrobblingSchema < ActiveRecord::Migration[8.0]
  def change
    # Enable UUID extension
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Create artists table (canonical artist data from MusicBrainz)
    create_table :artists, id: :uuid do |t|
      t.string :name, null: false
      t.string :musicbrainz_artist_id
      t.string :image_url
      t.text :bio

      t.timestamps
    end

    add_index :artists, :musicbrainz_artist_id, unique: true
    add_index :artists, :name

    # Create albums table (canonical album data from MusicBrainz)
    create_table :albums, id: :uuid do |t|
      t.string :name, null: false
      t.references :artist, type: :uuid, foreign_key: true
      t.string :musicbrainz_release_id
      t.string :cover_art_url
      t.date :release_date

      t.timestamps
    end

    add_index :albums, :musicbrainz_release_id, unique: true
    add_index :albums, :name

    # Create tracks table (canonical track data from MusicBrainz)
    create_table :tracks, id: :uuid do |t|
      t.string :name, null: false
      t.references :artist, type: :uuid, foreign_key: true
      t.references :album, type: :uuid, foreign_key: true
      t.integer :duration_ms
      t.string :musicbrainz_recording_id
      t.string :isrc

      t.timestamps
    end

    add_index :tracks, :musicbrainz_recording_id, unique: true
    add_index :tracks, :name

    # Create scrobbles table
    create_table :scrobbles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true
      t.references :track, type: :uuid, foreign_key: true

      # Raw data from client
      t.string :track_name, null: false
      t.string :artist_name, null: false
      t.string :album_name
      t.integer :duration_ms, null: false
      t.datetime :played_at, null: false
      t.string :source_app, null: false
      t.string :source_device

      # MusicBrainz enrichment
      t.string :musicbrainz_recording_id
      t.integer :metadata_status, default: 0, null: false

      t.timestamps
    end

    # Performance indexes as specified in PRD
    add_index :scrobbles, [:user_id, :played_at], order: { played_at: :desc }
    add_index :scrobbles, [:metadata_status, :created_at]
    add_index :scrobbles, [:user_id, :track_name, :artist_name, :played_at], name: 'index_scrobbles_duplicate_check'
  end
end
