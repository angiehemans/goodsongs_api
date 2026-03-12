class AddSinglePostLayoutToProfileThemes < ActiveRecord::Migration[7.1]
  def change
    add_column :profile_themes, :single_post_layout, :jsonb, default: {}, null: false
    add_column :profile_themes, :draft_single_post_layout, :jsonb
  end
end
