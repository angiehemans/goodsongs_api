class UserMailer < ApplicationMailer
  # Email confirmation
  def confirmation_email(user)
    @user = user
    @confirmation_url = "#{frontend_url}/confirm-email?token=#{user.email_confirmation_token}"
    @expiry_hours = User::EMAIL_CONFIRMATION_EXPIRY / 1.hour

    mail(
      to: @user.email,
      subject: 'Confirm your GoodSongs account'
    )
  end

  # Password reset
  def password_reset_email(user)
    @user = user
    @reset_url = "#{frontend_url}/reset-password?token=#{user.password_reset_token}"
    @expiry_hours = User::PASSWORD_RESET_EXPIRY / 1.hour

    mail(
      to: @user.email,
      subject: 'Reset your GoodSongs password'
    )
  end

  # Welcome email (sent after confirmation)
  def welcome_email(user)
    @user = user
    @login_url = "#{frontend_url}/login"
    @explore_url = "#{frontend_url}/discover"

    mail(
      to: @user.email,
      subject: 'Welcome to GoodSongs!'
    )
  end
end
