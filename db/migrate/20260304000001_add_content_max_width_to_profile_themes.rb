# frozen_string_literal: true

class AddContentMaxWidthToProfileThemes < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_themes, :content_max_width, :integer, default: 1200
  end
end
