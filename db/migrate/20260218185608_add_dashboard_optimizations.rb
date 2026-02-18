# frozen_string_literal: true

class AddDashboardOptimizations < ActiveRecord::Migration[8.0]
  def change
    # Add counter caches to users table for fast counts
    add_column :users, :followers_count, :integer, default: 0, null: false
    add_column :users, :following_count, :integer, default: 0, null: false
    add_column :users, :reviews_count, :integer, default: 0, null: false

    # Add indexes for ordered queries on follows
    # These help with "get followers/following sorted by most recent"
    add_index :follows, [:followed_id, :created_at], order: { created_at: :desc },
              name: 'index_follows_on_followed_id_and_created_at_desc'
    add_index :follows, [:follower_id, :created_at], order: { created_at: :desc },
              name: 'index_follows_on_follower_id_and_created_at_desc'
  end
end
