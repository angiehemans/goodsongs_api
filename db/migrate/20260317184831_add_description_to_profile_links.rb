class AddDescriptionToProfileLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_links, :description, :string
  end
end
