class CreateConnectedAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :connected_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :platform_user_id
      t.string :platform_username
      t.string :access_token
      t.string :account_type
      t.boolean :auto_post_recommendations, default: false
      t.boolean :auto_post_band_posts, default: false
      t.boolean :auto_post_events, default: false
      t.boolean :needs_reauth, default: false
      t.datetime :token_expires_at

      t.timestamps
    end

    add_index :connected_accounts, [:user_id, :platform], unique: true
  end
end
