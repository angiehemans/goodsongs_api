class FixExistingUsersOnboarding < ActiveRecord::Migration[8.0]
  def up
    # Set all existing users to FAN account type with onboarding completed
    execute <<-SQL
      UPDATE users
      SET account_type = 0, onboarding_completed = true
      WHERE onboarding_completed = false OR account_type IS NULL
    SQL
  end

  def down
    # No-op - we don't want to undo this
  end
end
