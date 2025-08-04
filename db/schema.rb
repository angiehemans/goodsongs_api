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

ActiveRecord::Schema[8.0].define(version: 2025_08_04_220530) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "bands", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location"
    t.string "spotify_link"
    t.string "bandcamp_link"
    t.string "apple_music_link"
    t.string "youtube_music_link"
    t.text "about"
    t.bigint "user_id"
    t.string "slug"
    t.index ["created_at"], name: "index_bands_on_created_at"
    t.index ["name"], name: "index_bands_on_name"
    t.index ["slug"], name: "index_bands_on_slug", unique: true
    t.index ["user_id"], name: "index_bands_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "song_link"
    t.string "band_name"
    t.string "song_name"
    t.string "artwork_url"
    t.bigint "band_id", null: false
    t.bigint "user_id", null: false
    t.text "review_text"
    t.integer "overall_rating"
    t.text "liked_aspects"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id", "created_at"], name: "index_reviews_on_band_id_and_created_at"
    t.index ["band_id"], name: "index_reviews_on_band_id"
    t.index ["created_at"], name: "index_reviews_on_created_at"
    t.index ["user_id", "created_at"], name: "index_reviews_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "username", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "spotify_access_token"
    t.text "spotify_refresh_token"
    t.datetime "spotify_expires_at"
    t.text "about_me"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["spotify_expires_at"], name: "index_users_on_spotify_expires_at"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bands", "users"
  add_foreign_key "reviews", "bands"
  add_foreign_key "reviews", "users"
end
