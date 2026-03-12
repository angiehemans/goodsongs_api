class AddCounterCaches < ActiveRecord::Migration[8.0]
  def up
    # Review likes and comments counter caches
    add_column :reviews, :review_likes_count, :integer, default: 0, null: false
    add_column :reviews, :review_comments_count, :integer, default: 0, null: false

    # Band reviews counter cache
    add_column :bands, :reviews_count, :integer, default: 0, null: false

    # Post likes and comments counter caches
    add_column :posts, :post_likes_count, :integer, default: 0, null: false
    add_column :posts, :post_comments_count, :integer, default: 0, null: false

    # Backfill counts
    execute <<~SQL
      UPDATE reviews SET review_likes_count = (SELECT COUNT(*) FROM review_likes WHERE review_likes.review_id = reviews.id)
    SQL
    execute <<~SQL
      UPDATE reviews SET review_comments_count = (SELECT COUNT(*) FROM review_comments WHERE review_comments.review_id = reviews.id)
    SQL
    execute <<~SQL
      UPDATE bands SET reviews_count = (SELECT COUNT(*) FROM reviews WHERE reviews.band_id = bands.id)
    SQL
    execute <<~SQL
      UPDATE posts SET post_likes_count = (SELECT COUNT(*) FROM post_likes WHERE post_likes.post_id = posts.id)
    SQL
    execute <<~SQL
      UPDATE posts SET post_comments_count = (SELECT COUNT(*) FROM post_comments WHERE post_comments.post_id = posts.id)
    SQL
  end

  def down
    remove_column :reviews, :review_likes_count
    remove_column :reviews, :review_comments_count
    remove_column :bands, :reviews_count
    remove_column :posts, :post_likes_count
    remove_column :posts, :post_comments_count
  end
end
