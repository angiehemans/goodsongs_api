class CreateAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :abilities do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.timestamps
    end

    add_index :abilities, :key, unique: true
    add_index :abilities, :category
  end
end
