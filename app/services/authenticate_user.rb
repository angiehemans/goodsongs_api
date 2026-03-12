# app/services/authenticate_user.rb
class AuthenticateUser
  attr_reader :access_token, :refresh_token, :user

  def initialize(email, password, request: nil, device_name: nil)
    @email = email
    @password = password
    @request = request
    @device_name = device_name
  end

  def call
    authenticate_user!

    # Generate access token (short-lived, 1 hour)
    @access_token = JsonWebToken.encode(user_id: @user.id)

    # Generate refresh token (long-lived, 90 days)
    raw_refresh_token, _refresh_token_record = RefreshToken.generate_for(
      @user,
      request: @request,
      device_name: @device_name
    )
    @refresh_token = raw_refresh_token

    self
  end

  private

  attr_reader :email, :password, :request, :device_name

  # Constant-time authentication to prevent email enumeration via timing
  DUMMY_PASSWORD_HASH = BCrypt::Password.create("dummy_password_for_timing_safety").to_s.freeze

  def authenticate_user!
    @user = User.find_by(email: email)

    if @user.nil?
      # Perform a dummy bcrypt comparison so the response time is consistent
      # whether or not the email exists
      BCrypt::Password.new(DUMMY_PASSWORD_HASH).is_password?(password)
      raise(ExceptionHandler::AuthenticationError, Message.invalid_credentials)
    end

    raise(ExceptionHandler::AuthenticationError, Message.account_disabled) if @user.disabled?
    raise(ExceptionHandler::AuthenticationError, Message.invalid_credentials) unless @user.authenticate(password)
  end
end
