# frozen_string_literal: true

class AddSocialLinksToUsersAndBands < ActiveRecord::Migration[8.0]
  def change
    # Social links for users (primarily for bloggers, but available to all)
    add_column :users, :instagram_url, :string
    add_column :users, :threads_url, :string
    add_column :users, :bluesky_url, :string
    add_column :users, :twitter_url, :string
    add_column :users, :tumblr_url, :string
    add_column :users, :tiktok_url, :string
    add_column :users, :facebook_url, :string
    add_column :users, :youtube_url, :string

    # Social links for bands
    add_column :bands, :instagram_url, :string
    add_column :bands, :threads_url, :string
    add_column :bands, :bluesky_url, :string
    add_column :bands, :twitter_url, :string
    add_column :bands, :tumblr_url, :string
    add_column :bands, :tiktok_url, :string
    add_column :bands, :facebook_url, :string
    add_column :bands, :youtube_url, :string
  end
end
