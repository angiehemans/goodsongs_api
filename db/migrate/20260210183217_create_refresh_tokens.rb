class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :device_name
      t.string :device_type  # 'mobile', 'web', 'desktop'
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :refresh_tokens, :token_digest, unique: true
    add_index :refresh_tokens, [:user_id, :revoked_at]
    add_index :refresh_tokens, :expires_at
  end
end
