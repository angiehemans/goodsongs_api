class SetAdminUser < ActiveRecord::Migration[8.0]
  def up
    admin_email = ENV['ADMIN_EMAIL']

    if admin_email.present?
      execute <<-SQL
        UPDATE users SET admin = true WHERE email = '#{admin_email}'
      SQL
    end
  end

  def down
    admin_email = ENV['ADMIN_EMAIL']

    if admin_email.present?
      execute <<-SQL
        UPDATE users SET admin = false WHERE email = '#{admin_email}'
      SQL
    end
  end
end
