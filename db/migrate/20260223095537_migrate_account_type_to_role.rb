class MigrateAccountTypeToRole < ActiveRecord::Migration[8.0]
  def up
    # Backfill role from account_type for existing users
    execute <<-SQL
      UPDATE users
      SET role = CASE account_type
        WHEN 0 THEN 'fan'
        WHEN 1 THEN 'band'
        WHEN 2 THEN 'blogger'
      END
      WHERE role IS NULL AND account_type IS NOT NULL
    SQL

    # Set admin users to 'fan' role (admins are typically platform testers)
    execute <<-SQL
      UPDATE users
      SET role = 'fan'
      WHERE admin = true
    SQL

    # Assign default plans to users who don't have one
    # Plans are guaranteed to exist from the previous migration (seed_rbac_data)
    User.reset_column_information
    User.where(plan_id: nil).find_each do |user|
      default_plan = Plan.default_for_role(user.role)
      user.update_column(:plan_id, default_plan&.id) if default_plan
    end

    # Remove the account_type column
    remove_column :users, :account_type
  end

  def down
    # Re-add account_type column
    add_column :users, :account_type, :integer

    # Backfill account_type from role
    execute <<-SQL
      UPDATE users
      SET account_type = CASE role
        WHEN 'fan' THEN 0
        WHEN 'band' THEN 1
        WHEN 'blogger' THEN 2
      END
      WHERE account_type IS NULL AND role IS NOT NULL
    SQL
  end
end
