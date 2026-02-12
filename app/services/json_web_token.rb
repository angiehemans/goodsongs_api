# app/services/json_web_token.rb
class JsonWebToken
  SECRET_KEY = ENV['JWT_SECRET_KEY'] || ENV['SECRET_KEY_BASE'] || Rails.application.secret_key_base

  # Access tokens are short-lived (1 hour)
  # Use refresh tokens to get new access tokens
  ACCESS_TOKEN_EXPIRATION = 1.hour

  def self.encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new decoded
  rescue JWT::ExpiredSignature
    raise ExceptionHandler::ExpiredToken, 'Token has expired'
  rescue JWT::DecodeError => e
    raise ExceptionHandler::InvalidToken, e.message
  end
end
