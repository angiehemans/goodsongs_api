class CreateEventCommentLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :event_comment_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event_comment, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_comment_likes, [:user_id, :event_comment_id], unique: true
  end
end
