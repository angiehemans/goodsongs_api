class AddSoundcloudLinkToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :soundcloud_link, :string
  end
end
