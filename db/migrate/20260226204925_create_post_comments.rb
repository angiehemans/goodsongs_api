class CreatePostComments < ActiveRecord::Migration[8.0]
  def change
    create_table :post_comments do |t|
      t.references :user, foreign_key: true, null: true  # NULLABLE for anonymous
      t.references :post, null: false, foreign_key: true
      t.text :body, null: false
      t.string :guest_name      # For anonymous
      t.string :guest_email     # For anonymous (never exposed in API)
      t.string :claim_token     # For linking after signup
      t.datetime :claimed_at
      t.timestamps
    end

    add_index :post_comments, [:post_id, :created_at]
    add_index :post_comments, :claim_token, unique: true, where: "claim_token IS NOT NULL"
  end
end
