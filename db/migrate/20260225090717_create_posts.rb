class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true

      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt
      t.text :body

      t.datetime :publish_date
      t.integer :status, default: 0, null: false
      t.boolean :featured, default: false, null: false

      t.jsonb :tags, default: []
      t.jsonb :categories, default: []
      t.jsonb :authors, default: []

      t.timestamps
    end

    # Slug only unique within user's posts (not globally)
    add_index :posts, [:user_id, :slug], unique: true
    add_index :posts, [:user_id, :status, :publish_date]
    add_index :posts, [:user_id, :featured, :publish_date], name: 'index_posts_featured_by_date'
    add_index :posts, :tags, using: :gin
    add_index :posts, :categories, using: :gin
  end
end
