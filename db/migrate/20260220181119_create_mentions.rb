class CreateMentions < ActiveRecord::Migration[8.0]
  def change
    create_table :mentions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mentioner, null: false, foreign_key: { to_table: :users }
      t.references :mentionable, polymorphic: true, null: false
      t.timestamps
    end

    add_index :mentions, [:mentionable_type, :mentionable_id, :user_id], unique: true, name: 'index_mentions_uniqueness'
  end
end
