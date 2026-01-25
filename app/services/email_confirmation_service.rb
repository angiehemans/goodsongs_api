class EmailConfirmationService
  class TokenExpired < StandardError; end
  class TokenInvalid < StandardError; end
  class AlreadyConfirmed < StandardError; end

  def initialize(token)
    @token = token
  end

  def call
    validate_token!
    confirm_user!
    send_welcome_email
    @user
  end

  private

  def validate_token!
    raise TokenInvalid if @token.blank?

    @user = User.find_by(email_confirmation_token: @token)
    raise TokenInvalid unless @user
    raise AlreadyConfirmed if @user.email_confirmed?
    raise TokenExpired unless @user.email_confirmation_token_valid?
  end

  def confirm_user!
    @user.confirm_email!
  end

  def send_welcome_email
    UserMailerJob.perform_later(@user.id, :welcome)
  end
end
