class AddStructuredLocationToBands < ActiveRecord::Migration[8.0]
  def change
    # Rename existing location to city
    rename_column :bands, :location, :city

    # Add region and geocoding fields
    add_column :bands, :region, :string
    add_column :bands, :latitude, :float
    add_column :bands, :longitude, :float

    add_index :bands, [:latitude, :longitude]
  end
end
