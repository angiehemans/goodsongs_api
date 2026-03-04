class CreateProfileAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_assets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :purpose, default: 'background'
      t.timestamps
    end

    add_index :profile_assets, [:user_id, :purpose]
  end
end
