class CreateVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :venues do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.string :city
      t.string :region
      t.float :latitude
      t.float :longitude
      t.timestamps

      t.index [:latitude, :longitude]
      t.index :name
    end
  end
end
