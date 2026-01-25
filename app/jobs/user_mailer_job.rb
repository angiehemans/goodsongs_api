class UserMailerJob < ApplicationJob
  queue_as :mailers

  # Retry on transient failures
  retry_on Net::OpenTimeout, Net::ReadTimeout,
           wait: :polynomially_longer, attempts: 5

  # Discard if user no longer exists
  discard_on ActiveJob::DeserializationError

  def perform(user_id, email_type)
    user = User.find_by(id: user_id)
    return unless user # User was deleted

    case email_type.to_sym
    when :confirmation
      return if user.email_confirmed? # Already confirmed
      return unless user.email_confirmation_token.present?
      UserMailer.confirmation_email(user).deliver_now

    when :password_reset
      return unless user.password_reset_token.present?
      return unless user.password_reset_token_valid?
      UserMailer.password_reset_email(user).deliver_now

    when :welcome
      UserMailer.welcome_email(user).deliver_now

    else
      Rails.logger.warn("UserMailerJob: Unknown email type: #{email_type}")
    end
  end
end
