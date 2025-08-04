class AddIndexesForPerformance < ActiveRecord::Migration[8.0]
  def change
    # Index for reviews ordered by created_at (used in feeds and ordering)
    add_index :reviews, :created_at
    
    # Index for bands ordered by created_at (used in user bands)
    add_index :bands, :created_at
    
    # Index for Spotify token expiration checks
    add_index :users, :spotify_expires_at
    
    # Index for band lookups by name (used in find_or_create_by)
    add_index :bands, :name
    
    # Composite index for user reviews (frequently accessed together)
    add_index :reviews, [:user_id, :created_at]
    
    # Composite index for band reviews (frequently accessed together)
    add_index :reviews, [:band_id, :created_at]
  end
end