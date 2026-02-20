class CreateReviewCommentLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :review_comment_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review_comment, null: false, foreign_key: true
      t.timestamps
    end

    add_index :review_comment_likes, [:user_id, :review_comment_id], unique: true
  end
end
