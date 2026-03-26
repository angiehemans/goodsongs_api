class ThreadsOauthService
  BASE_URL = "https://graph.threads.net".freeze
  AUTH_URL = "https://threads.net/oauth/authorize".freeze

  def initialize
    @client_id = ENV.fetch("THREADS_CLIENT_ID")
    @client_secret = ENV.fetch("THREADS_CLIENT_SECRET")
    @redirect_uri = ENV.fetch("THREADS_REDIRECT_URI")
  end

  def authorize_url(state:)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      scope: "threads_basic,threads_content_publish",
      response_type: "code",
      state: state
    }
    "#{AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  def exchange_code(code:)
    uri = URI("#{BASE_URL}/oauth/access_token")
    response = Net::HTTP.post_form(uri, {
      client_id: @client_id,
      client_secret: @client_secret,
      grant_type: "authorization_code",
      redirect_uri: @redirect_uri,
      code: code
    })
    JSON.parse(response.body)
  end

  def exchange_for_long_lived_token(short_lived_token:)
    uri = URI("#{BASE_URL}/access_token")
    uri.query = URI.encode_www_form({
      grant_type: "th_exchange_token",
      client_secret: @client_secret,
      access_token: short_lived_token
    })
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end

  def refresh_token(token:)
    uri = URI("#{BASE_URL}/refresh_access_token")
    uri.query = URI.encode_www_form({
      grant_type: "th_refresh_token",
      access_token: token
    })
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end

  def fetch_profile(token:)
    uri = URI("#{BASE_URL}/v1.0/me")
    uri.query = URI.encode_www_form({
      fields: "id,username",
      access_token: token
    })
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end
end
