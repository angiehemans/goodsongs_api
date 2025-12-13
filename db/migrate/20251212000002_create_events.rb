class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :band, null: false, foreign_key: true
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.datetime :event_date, null: false
      t.string :ticket_link
      t.string :image_url
      t.string :price
      t.string :age_restriction
      t.boolean :disabled, default: false
      t.timestamps

      t.index :event_date
      t.index [:event_date, :disabled]
    end
  end
end
