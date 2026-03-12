class AddCardBackgroundToProfileThemes < ActiveRecord::Migration[7.1]
  def change
    add_column :profile_themes, :card_background_color, :string
    add_column :profile_themes, :card_background_opacity, :integer, default: 10, null: false
  end
end
