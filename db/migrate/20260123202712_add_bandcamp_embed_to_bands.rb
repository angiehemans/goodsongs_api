class AddBandcampEmbedToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :bandcamp_embed, :text
  end
end
