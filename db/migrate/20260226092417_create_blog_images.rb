class CreateBlogImages < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_images do |t|
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
