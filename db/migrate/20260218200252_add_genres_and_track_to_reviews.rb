class AddGenresAndTrackToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :genres, :jsonb, default: []
    add_reference :reviews, :track, type: :uuid, foreign_key: true, index: true
  end
end
