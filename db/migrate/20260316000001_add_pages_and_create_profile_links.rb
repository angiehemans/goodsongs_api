class AddPagesAndCreateProfileLinks < ActiveRecord::Migration[8.0]
  def change
    # Add pages and draft_pages JSONB columns to profile_themes
    add_column :profile_themes, :pages, :jsonb, default: []
    add_column :profile_themes, :draft_pages, :jsonb, default: []

    # Create profile_links table for custom links on the link page
    create_table :profile_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :url, null: false
      t.string :icon
      t.integer :position, null: false, default: 0
      t.boolean :visible, null: false, default: true
      t.timestamps
    end

    add_index :profile_links, [:user_id, :position]
  end
end
