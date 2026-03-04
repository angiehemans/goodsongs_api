class CreateProfileThemes < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_themes do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :background_color, default: '#121212'
      t.string :brand_color, default: '#6366f1'
      t.string :font_color, default: '#f5f5f5'
      t.string :header_font, default: 'Inter'
      t.string :body_font, default: 'Inter'
      t.jsonb :sections, null: false, default: []
      t.jsonb :draft_sections
      t.datetime :published_at
      t.timestamps
    end
  end
end
