class AddAccountTypeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :account_type, :integer, default: 0, null: false
    add_column :users, :onboarding_completed, :boolean, default: false, null: false

    # Set existing users to FAN (0) with onboarding completed
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE users SET account_type = 0, onboarding_completed = true
        SQL
      end
    end

    add_index :users, :account_type
  end
end
