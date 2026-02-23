class CreatePlanAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_abilities do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :ability, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :plan_abilities, [:plan_id, :ability_id], unique: true
  end
end
