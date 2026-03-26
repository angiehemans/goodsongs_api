class SocialPostService
  ReauthRequired = Class.new(StandardError)
  RateLimited = Class.new(StandardError)

  private

  def handle_response(response)
    case response.code.to_i
    when 200, 201
      JSON.parse(response.body)
    when 401
      raise ReauthRequired, "Token is invalid or expired"
    when 429
      raise RateLimited, "Rate limit exceeded"
    else
      Rails.logger.error("Social post failed (#{response.code}): #{response.body}")
      nil
    end
  end

  def post_json(uri, body, token)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    http.request(request)
  end
end
