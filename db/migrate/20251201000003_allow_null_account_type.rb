class AllowNullAccountType < ActiveRecord::Migration[8.0]
  def change
    # Allow null account_type for new users (they choose during onboarding)
    change_column_null :users, :account_type, true
    change_column_default :users, :account_type, from: 0, to: nil

    # Existing users with onboarding_completed should keep their account_type
    # New users will have account_type = null until they complete onboarding step 1
  end
end
