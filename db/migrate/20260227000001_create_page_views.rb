# frozen_string_literal: true

class CreatePageViews < ActiveRecord::Migration[8.0]
  def change
    create_table :page_views do |t|
      t.string :viewable_type, null: false
      t.bigint :viewable_id, null: false
      t.bigint :owner_id, null: false
      t.string :referrer
      t.string :referrer_source, null: false, default: "direct"
      t.string :path, null: false
      t.string :session_id, null: false
      t.string :ip_hash, null: false
      t.string :user_agent
      t.string :device_type, null: false, default: "desktop"
      t.string :country
      t.datetime :created_at, null: false
    end

    add_index :page_views, [:owner_id, :created_at]
    add_index :page_views, [:viewable_type, :viewable_id, :created_at], name: 'index_page_views_on_viewable_and_created_at'
    add_index :page_views, [:owner_id, :referrer_source, :created_at], name: 'index_page_views_on_owner_referrer_created_at'
    add_index :page_views, :created_at
  end
end
