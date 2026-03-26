class AddFontWeightsToProfileThemes < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_themes, :header_font_weight, :integer, default: 400
    add_column :profile_themes, :body_font_weight, :integer, default: 400
  end
end
