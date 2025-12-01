class UpdateUsersForOnboardingFlow < ActiveRecord::Migration[8.0]
  def change
    # Make username nullable - BAND accounts won't have usernames
    change_column_null :users, :username, true

    # Add primary_band_id for BAND accounts - their main band identity
    add_reference :users, :primary_band, foreign_key: { to_table: :bands }, null: true
  end
end
