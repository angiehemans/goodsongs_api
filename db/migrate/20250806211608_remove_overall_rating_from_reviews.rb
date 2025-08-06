class RemoveOverallRatingFromReviews < ActiveRecord::Migration[8.0]
  def change
    remove_column :reviews, :overall_rating, :integer
  end
end
