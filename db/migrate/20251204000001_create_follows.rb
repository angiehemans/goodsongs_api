class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Ensure a user can only follow another user once
    # Note: t.references already creates individual indexes on follower_id and followed_id
    add_index :follows, [:follower_id, :followed_id], unique: true
  end
end
