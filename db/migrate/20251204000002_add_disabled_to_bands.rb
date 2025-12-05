class AddDisabledToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :disabled, :boolean, default: false, null: false
  end
end
