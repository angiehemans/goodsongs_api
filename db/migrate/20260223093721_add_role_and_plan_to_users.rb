class AddRoleAndPlanToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string
    add_reference :users, :plan, foreign_key: true
    add_index :users, :role
  end
end
