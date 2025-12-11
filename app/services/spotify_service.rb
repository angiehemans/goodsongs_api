class SpotifyService
  include HTTParty
  base_uri 'https://api.spotify.com/v1'

  def initialize(user)
    @user = user
    @access_token = user.spotify_access_token
  end

  def recently_played(limit: 20)
    return { error: 'No Spotify access token found' } unless @access_token

    # Check if token is expired and refresh if needed
    if token_expired?
      refresh_result = refresh_access_token
      return refresh_result if refresh_result[:error]
    end

    response = self.class.get(
      '/me/player/recently-played',
      query: { limit: limit },
      headers: authorization_headers
    )

    if response.success?
      format_recently_played_response(response.parsed_response)
    else
      handle_api_error(response)
    end
  end

  def user_profile
    return { error: 'No Spotify access token found' } unless @access_token

    if token_expired?
      refresh_result = refresh_access_token
      return refresh_result if refresh_result[:error]
    end

    response = self.class.get('/me', headers: authorization_headers)

    if response.success?
      response.parsed_response
    else
      handle_api_error(response)
    end
  end

  private

  def authorization_headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def token_expired?
    return true unless @user.spotify_expires_at
    @user.spotify_expires_at <= Time.current
  end

  def refresh_access_token
    return { error: 'No refresh token available' } unless @user.spotify_refresh_token

    response = HTTParty.post(
      'https://accounts.spotify.com/api/token',
      body: {
        grant_type: 'refresh_token',
        refresh_token: @user.spotify_refresh_token,
        client_id: ENV['SPOTIFY_CLIENT_ID'],
        client_secret: ENV['SPOTIFY_CLIENT_SECRET']
      },
      headers: {
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    )

    if response.success?
      new_token = response['access_token']
      expires_in = response['expires_in']
      
      @user.update!(
        spotify_access_token: new_token,
        spotify_expires_at: Time.current + expires_in.seconds
      )
      
      @access_token = new_token
      { success: true }
    else
      { error: "Failed to refresh token: #{response.body}" }
    end
  end

  def format_recently_played_response(data)
    return { tracks: [] } unless data['items']

    tracks = data['items'].map do |item|
      track = item['track']
      {
        id: track['id'],
        name: track['name'],
        artists: track['artists'].map { |artist|
          {
            name: artist['name'],
            spotify_url: artist['external_urls']['spotify']
          }
        },
        album: {
          name: track['album']['name'],
          images: track['album']['images']
        },
        external_urls: track['external_urls'],
        played_at: item['played_at'],
        duration_ms: track['duration_ms'],
        preview_url: track['preview_url']
      }
    end

    { tracks: tracks }
  end

  def handle_api_error(response)
    case response.code
    when 401
      # Token might be invalid, try refreshing
      if @user.spotify_refresh_token
        refresh_result = refresh_access_token
        return refresh_result if refresh_result[:error]
        # Retry the original request
        return { error: 'Token refresh succeeded but retry needed' }
      else
        { error: 'Spotify authorization expired. Please reconnect your account.' }
      end
    when 403
      { error: 'Insufficient permissions to access Spotify data' }
    when 429
      { error: 'Spotify API rate limit exceeded. Please try again later.' }
    else
      { error: "Spotify API error: #{response.code} - #{response.body}" }
    end
  end
end