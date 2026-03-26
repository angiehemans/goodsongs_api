class InstagramOauthService
  AUTH_URL = "https://www.instagram.com/oauth/authorize".freeze
  GRAPH_URL = "https://graph.instagram.com".freeze
  API_URL = "https://api.instagram.com".freeze

  def initialize
    @client_id = ENV.fetch("INSTAGRAM_CLIENT_ID")
    @client_secret = ENV.fetch("INSTAGRAM_CLIENT_SECRET")
    @redirect_uri = ENV.fetch("INSTAGRAM_REDIRECT_URI")
  end

  def authorize_url(state:)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      scope: "instagram_basic,instagram_content_publish",
      response_type: "code",
      state: state
    }
    "#{AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  def exchange_code(code:)
    uri = URI("#{API_URL}/oauth/access_token")
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
    uri = URI("#{GRAPH_URL}/access_token")
    uri.query = URI.encode_www_form({
      grant_type: "ig_exchange_token",
      client_secret: @client_secret,
      access_token: short_lived_token
    })
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end

  def refresh_token(token:)
    uri = URI("#{GRAPH_URL}/refresh_access_token")
    uri.query = URI.encode_www_form({
      grant_type: "ig_refresh_token",
      access_token: token
    })
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end

  def fetch_profile(token:)
    uri = URI("#{GRAPH_URL}/v21.0/me")
    uri.query = URI.encode_www_form({
      fields: "id,username,account_type",
      access_token: token
    })
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end
end
