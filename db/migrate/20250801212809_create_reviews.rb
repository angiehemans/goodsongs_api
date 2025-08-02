class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.string :song_link
      t.string :band_name
      t.string :song_name
      t.string :artwork_url
      t.references :band, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :review_text
      t.integer :overall_rating
      t.text :liked_aspects

      t.timestamps
    end
  end
end
