class AddAdminToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :admin, :boolean, default: false, null: false

    # Set admin for the configured admin email
    admin_email = ENV.fetch('ADMIN_EMAIL', nil)
    if admin_email.present?
      execute <<-SQL
        UPDATE users SET admin = true WHERE LOWER(email) = LOWER('#{admin_email}')
      SQL
    end
  end

  def down
    remove_column :users, :admin
  end
end
