class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :role, null: false
      t.integer :price_cents_monthly, default: 0, null: false
      t.integer :price_cents_annual, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :plans, :key, unique: true
    add_index :plans, :role
    add_index :plans, :active
  end
end
