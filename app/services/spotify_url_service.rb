class SpotifyUrlService
  SPOTIFY_BASE_URL = 'https://accounts.spotify.com/authorize'
  SCOPE = 'user-read-recently-played user-read-email'

  def self.authorization_url(user_id, redirect_uri = nil)
    redirect_uri ||= default_redirect_uri
    
    params = {
      client_id: ENV['SPOTIFY_CLIENT_ID'],
      response_type: 'code',
      redirect_uri: redirect_uri,
      scope: SCOPE,
      state: user_id
    }
    
    "#{SPOTIFY_BASE_URL}?#{params.to_query}"
  end

  def self.default_redirect_uri
    frontend_url = ENV['FRONTEND_URL'] || 'http://localhost:3000'
    "#{frontend_url}/auth/spotify/callback"
  end

  private_class_method :default_redirect_uri
end