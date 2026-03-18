class AddBorderRadiusToProfileThemes < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_themes, :border_radius, :integer, default: 8
  end
end
