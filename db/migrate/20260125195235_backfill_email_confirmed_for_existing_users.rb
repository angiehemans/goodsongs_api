class BackfillEmailConfirmedForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    # Grandfather all existing users by marking their emails as confirmed
    # These users signed up before email verification was implemented
    User.where(email_confirmed: false).update_all(
      email_confirmed: true,
      email_confirmation_token: nil,
      email_confirmation_sent_at: nil
    )
  end

  def down
    # No-op: We can't know which users were grandfathered vs actually verified
  end
end
