class CreateEventLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :event_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_likes, [:user_id, :event_id], unique: true
    add_column :events, :event_likes_count, :integer, default: 0, null: false
  end
end
