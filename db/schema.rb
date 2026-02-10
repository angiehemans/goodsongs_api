# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_10_015014) do
  create_schema "musicbrainz_staging"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "albums", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "musicbrainz_release_id"
    t.string "cover_art_url"
    t.date "release_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "band_id"
    t.integer "source", default: 0, null: false
    t.string "discogs_master_id"
    t.string "release_type"
    t.jsonb "genres", default: []
    t.string "label"
    t.string "country"
    t.integer "track_count"
    t.boolean "verified", default: false, null: false
    t.bigint "submitted_by_id"
    t.string "audiodb_album_id"
    t.index ["audiodb_album_id"], name: "index_albums_on_audiodb_album_id", unique: true, where: "(audiodb_album_id IS NOT NULL)"
    t.index ["band_id"], name: "index_albums_on_band_id"
    t.index ["discogs_master_id"], name: "index_albums_on_discogs_master_id", unique: true
    t.index ["musicbrainz_release_id"], name: "index_albums_on_musicbrainz_release_id", unique: true
    t.index ["name"], name: "index_albums_on_name"
    t.index ["name"], name: "index_albums_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["submitted_by_id"], name: "index_albums_on_submitted_by_id"
  end

  create_table "band_aliases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "band_id", null: false
    t.string "name", null: false
    t.string "locale"
    t.datetime "created_at", null: false
    t.index ["band_id"], name: "index_band_aliases_on_band_id"
    t.index ["name"], name: "index_band_aliases_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "bands", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "city"
    t.string "spotify_link"
    t.string "bandcamp_link"
    t.string "apple_music_link"
    t.string "youtube_music_link"
    t.text "about"
    t.bigint "user_id"
    t.string "slug"
    t.string "region"
    t.float "latitude"
    t.float "longitude"
    t.boolean "disabled", default: false, null: false
    t.string "musicbrainz_id"
    t.string "external_image_url"
    t.string "artist_image_url"
    t.string "lastfm_artist_name"
    t.string "lastfm_image_url"
    t.text "bandcamp_embed"
    t.integer "source", default: 0, null: false
    t.string "discogs_artist_id"
    t.string "country"
    t.string "artist_type"
    t.string "sort_name"
    t.jsonb "aliases", default: []
    t.jsonb "genres", default: []
    t.boolean "verified", default: false, null: false
    t.bigint "submitted_by_id"
    t.string "audiodb_artist_id"
    t.index ["audiodb_artist_id"], name: "index_bands_on_audiodb_artist_id", unique: true, where: "(audiodb_artist_id IS NOT NULL)"
    t.index ["created_at"], name: "index_bands_on_created_at"
    t.index ["latitude", "longitude"], name: "index_bands_on_latitude_and_longitude"
    t.index ["musicbrainz_id"], name: "index_bands_on_musicbrainz_id", unique: true
    t.index ["name"], name: "index_bands_on_name"
    t.index ["name"], name: "index_bands_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_bands_on_slug", unique: true
    t.index ["submitted_by_id"], name: "index_bands_on_submitted_by_id"
    t.index ["user_id"], name: "index_bands_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "band_id", null: false
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "event_date", null: false
    t.string "ticket_link"
    t.string "image_url"
    t.string "price"
    t.string "age_restriction"
    t.boolean "disabled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_events_on_band_id"
    t.index ["event_date", "disabled"], name: "index_events_on_event_date_and_disabled"
    t.index ["event_date"], name: "index_events_on_event_date"
    t.index ["venue_id"], name: "index_events_on_venue_id"
  end

  create_table "favorite_bands", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "band_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_favorite_bands_on_band_id"
    t.index ["user_id", "band_id"], name: "index_favorite_bands_on_user_id_and_band_id", unique: true
    t.index ["user_id", "position"], name: "index_favorite_bands_on_user_id_and_position"
    t.index ["user_id"], name: "index_favorite_bands_on_user_id"
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "follower_id", null: false
    t.bigint "followed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.bigint "actor_id"
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "review_comments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "review_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id", "created_at"], name: "index_review_comments_on_review_id_and_created_at"
    t.index ["review_id"], name: "index_review_comments_on_review_id"
    t.index ["user_id"], name: "index_review_comments_on_user_id"
  end

  create_table "review_likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "review_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_review_likes_on_review_id"
    t.index ["user_id", "review_id"], name: "index_review_likes_on_user_id_and_review_id", unique: true
    t.index ["user_id"], name: "index_review_likes_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "song_link"
    t.string "band_name"
    t.string "song_name"
    t.string "artwork_url"
    t.bigint "band_id", null: false
    t.bigint "user_id", null: false
    t.text "review_text"
    t.text "liked_aspects"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id", "created_at"], name: "index_reviews_on_band_id_and_created_at"
    t.index ["band_id"], name: "index_reviews_on_band_id"
    t.index ["created_at"], name: "index_reviews_on_created_at"
    t.index ["user_id", "created_at"], name: "index_reviews_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "scrobbles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.uuid "track_id"
    t.string "track_name", null: false
    t.string "artist_name", null: false
    t.string "album_name"
    t.integer "duration_ms", null: false
    t.datetime "played_at", null: false
    t.string "source_app", null: false
    t.string "source_device"
    t.string "musicbrainz_recording_id"
    t.integer "metadata_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metadata_status", "created_at"], name: "index_scrobbles_on_metadata_status_and_created_at"
    t.index ["track_id"], name: "index_scrobbles_on_track_id"
    t.index ["user_id", "played_at"], name: "index_scrobbles_on_user_id_and_played_at", order: { played_at: :desc }
    t.index ["user_id", "track_name", "artist_name", "played_at"], name: "index_scrobbles_duplicate_check"
    t.index ["user_id"], name: "index_scrobbles_on_user_id"
  end

  create_table "tracks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "album_id"
    t.integer "duration_ms"
    t.string "musicbrainz_recording_id"
    t.string "isrc"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "band_id"
    t.integer "source", default: 0, null: false
    t.string "discogs_track_id"
    t.integer "track_number"
    t.integer "disc_number", default: 1
    t.jsonb "genres", default: []
    t.boolean "verified", default: false, null: false
    t.bigint "submitted_by_id"
    t.string "audiodb_track_id"
    t.index ["album_id"], name: "index_tracks_on_album_id"
    t.index ["audiodb_track_id"], name: "index_tracks_on_audiodb_track_id", unique: true, where: "(audiodb_track_id IS NOT NULL)"
    t.index ["band_id"], name: "index_tracks_on_band_id"
    t.index ["musicbrainz_recording_id"], name: "index_tracks_on_musicbrainz_recording_id", unique: true
    t.index ["name"], name: "index_tracks_on_name"
    t.index ["name"], name: "index_tracks_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["submitted_by_id"], name: "index_tracks_on_submitted_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "spotify_access_token"
    t.text "spotify_refresh_token"
    t.datetime "spotify_expires_at"
    t.text "about_me"
    t.integer "account_type"
    t.boolean "onboarding_completed", default: false, null: false
    t.bigint "primary_band_id"
    t.boolean "admin", default: false, null: false
    t.boolean "disabled", default: false, null: false
    t.string "city"
    t.string "region"
    t.float "latitude"
    t.float "longitude"
    t.string "lastfm_username"
    t.boolean "email_confirmed", default: false, null: false
    t.string "email_confirmation_token"
    t.datetime "email_confirmation_sent_at"
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.index ["account_type"], name: "index_users_on_account_type"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email_confirmation_token"], name: "index_users_on_email_confirmation_token", unique: true
    t.index ["lastfm_username"], name: "index_users_on_lastfm_username"
    t.index ["latitude", "longitude"], name: "index_users_on_latitude_and_longitude"
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
    t.index ["primary_band_id"], name: "index_users_on_primary_band_id"
    t.index ["spotify_expires_at"], name: "index_users_on_spotify_expires_at"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "address", null: false
    t.string "city"
    t.string "region"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["latitude", "longitude"], name: "index_venues_on_latitude_and_longitude"
    t.index ["name"], name: "index_venues_on_name"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "albums", "bands"
  add_foreign_key "albums", "users", column: "submitted_by_id"
  add_foreign_key "band_aliases", "bands", on_delete: :cascade
  add_foreign_key "bands", "users"
  add_foreign_key "bands", "users", column: "submitted_by_id"
  add_foreign_key "events", "bands"
  add_foreign_key "events", "venues"
  add_foreign_key "favorite_bands", "bands"
  add_foreign_key "favorite_bands", "users"
  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "review_comments", "reviews"
  add_foreign_key "review_comments", "users"
  add_foreign_key "review_likes", "reviews"
  add_foreign_key "review_likes", "users"
  add_foreign_key "reviews", "bands"
  add_foreign_key "reviews", "users"
  add_foreign_key "scrobbles", "tracks"
  add_foreign_key "scrobbles", "users"
  add_foreign_key "tracks", "albums"
  add_foreign_key "tracks", "bands"
  add_foreign_key "tracks", "users", column: "submitted_by_id"
  add_foreign_key "users", "bands", column: "primary_band_id"
end
