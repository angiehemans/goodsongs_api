class AddMissingPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Trigram indexes for search (DiscoverController uses % operator)
    add_index :reviews, :band_name, name: "index_reviews_on_band_name_trgm",
              using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :reviews, :song_name, name: "index_reviews_on_song_name_trgm",
              using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :users, :username, name: "index_users_on_username_trgm",
              using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently

    # bands.discogs_artist_id used in ScrobbleEnrichmentService lookups
    add_index :bands, :discogs_artist_id, unique: true,
              where: "discogs_artist_id IS NOT NULL",
              name: "index_bands_on_discogs_artist_id",
              algorithm: :concurrently

    # page_views dedup check in TrackingController
    add_index :page_views, [:viewable_type, :viewable_id, :session_id, :created_at],
              name: "index_page_views_on_dedup",
              algorithm: :concurrently

    # users.disabled and onboarding_completed used in DiscoverController filters
    add_index :users, [:disabled, :onboarding_completed, :role],
              name: "index_users_on_disabled_onboarding_role",
              algorithm: :concurrently
  end
end
