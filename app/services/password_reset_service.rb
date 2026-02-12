class PasswordResetService
  class TokenExpired < StandardError; end
  class TokenInvalid < StandardError; end
  class InvalidPassword < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super('Invalid password')
    end
  end

  def initialize(token, new_password, new_password_confirmation)
    @token = token
    @new_password = new_password
    @new_password_confirmation = new_password_confirmation
  end

  def call
    validate_token!
    reset_password!
    @user
  end

  private

  def validate_token!
    raise TokenInvalid if @token.blank?

    # Rails 8's find_by_token_for handles expiration automatically
    @user = User.find_by_token_for(:password_reset, @token)
    raise TokenInvalid unless @user
  end

  def reset_password!
    @user.password = @new_password
    @user.password_confirmation = @new_password_confirmation

    unless @user.valid?
      raise InvalidPassword.new(@user.errors.full_messages)
    end

    # Token is automatically invalidated when password changes
    # (the token includes password_salt which changes with the password)
    @user.save!
  end
end
