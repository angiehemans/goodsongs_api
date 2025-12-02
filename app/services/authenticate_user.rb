# app/services/authenticate_user.rb
class AuthenticateUser
  def initialize(email, password)
    @email = email
    @password = password
  end

  def call
    JsonWebToken.encode(user_id: user.id) if user
  end

  private

  attr_reader :email, :password

  def user
    user = User.find_by(email: email)

    raise(ExceptionHandler::AuthenticationError, Message.account_disabled) if user&.disabled?
    return user if user && user.authenticate(password)

    raise(ExceptionHandler::AuthenticationError, Message.invalid_credentials)
  end
end
