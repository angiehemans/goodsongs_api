class RenameStateToRegion < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :state, :region
  end
end
