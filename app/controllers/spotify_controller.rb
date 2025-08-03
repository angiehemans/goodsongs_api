class SpotifyController < ApplicationController
  before_action :authenticate_request, except: [:callback, :connect]
  before_action :authenticate_request_optional, only: [:connect]

  def connect
    # Try to authenticate from auth_code parameter for browser-based flow
    if current_user.nil? && params[:auth_code].present?
      begin
        # Verify the temporary auth code from Rails cache
        user_id = Rails.cache.read("spotify_auth:#{params[:auth_code]}")
        if user_id
          @current_user = User.find(user_id)
          # Delete the one-time use code
          Rails.cache.delete("spotify_auth:#{params[:auth_code]}")
        end
      rescue
        @current_user = nil
      end
    end

    unless current_user
      if request.format.json?
        render json: { error: 'Authentication required' }, status: :unauthorized
      else
        render plain: 'Authentication required. Please use the secure flow from your app.', status: :unauthorized
      end
      return
    end

    # Use base_url but ensure it matches your Spotify app settings
    redirect_uri = "#{request.base_url}/auth/spotify/callback"
    puts "DEBUG: Redirect URI being used: #{redirect_uri}"
    scope = 'user-read-recently-played user-read-email'
    
    spotify_auth_url = "https://accounts.spotify.com/authorize?" +
      "client_id=#{ENV['SPOTIFY_CLIENT_ID']}&" +
      "response_type=code&" +
      "redirect_uri=#{CGI.escape(redirect_uri)}&" +
      "scope=#{CGI.escape(scope)}&" +
      "state=#{current_user.id}"
    
    # Return JSON for AJAX calls, redirect for direct browser visits
    if request.format.json?
      render json: { auth_url: spotify_auth_url }
    else
      redirect_to spotify_auth_url, allow_other_host: true
    end
  end

  def generate_connect_url
    # Generate a temporary, one-time use auth code
    auth_code = SecureRandom.hex(32)
    
    # Store user ID with the auth code for 5 minutes
    Rails.cache.write("spotify_auth:#{auth_code}", current_user.id, expires_in: 5.minutes)
    
    # Return the secure URL with the temporary code
    connect_url = "#{request.base_url}/spotify/connect?auth_code=#{auth_code}"
    
    render json: { connect_url: connect_url }
  end

  def connect_url
    # Use base_url but ensure it matches your Spotify app settings
    redirect_uri = "#{request.base_url}/auth/spotify/callback"
    puts "DEBUG: Redirect URI being used: #{redirect_uri}"
    scope = 'user-read-recently-played user-read-email'
    
    spotify_auth_url = "https://accounts.spotify.com/authorize?" +
      "client_id=#{ENV['SPOTIFY_CLIENT_ID']}&" +
      "response_type=code&" +
      "redirect_uri=#{CGI.escape(redirect_uri)}&" +
      "scope=#{CGI.escape(scope)}&" +
      "state=#{current_user.id}"
    
    render json: { auth_url: spotify_auth_url }
  end

  def callback
    auth_code = params[:code]
    state = params[:state]
    error = params[:error]

    if error
      render json: { error: "Spotify authorization failed: #{error}" }, status: :bad_request
      return
    end

    unless auth_code && state
      render json: { error: 'Missing authorization code or state' }, status: :bad_request
      return
    end

    # Find user by state parameter
    user = User.find_by(id: state)
    unless user
      render json: { error: 'Invalid state parameter' }, status: :bad_request
      return
    end

    # Exchange authorization code for access token
    token_response = exchange_code_for_token(auth_code)
    
    if token_response[:error]
      render json: { error: token_response[:error] }, status: :bad_request
      return
    end

    # Update user with Spotify tokens
    user.update!(
      spotify_access_token: token_response[:access_token],
      spotify_refresh_token: token_response[:refresh_token],
      spotify_expires_at: Time.current + token_response[:expires_in].seconds
    )

    # Redirect to frontend success page
    redirect_to "#{ENV['FRONTEND_URL'] || 'http://localhost:3000'}/dashboard?spotify=connected"
  end

  def disconnect
    current_user.update!(
      spotify_access_token: nil,
      spotify_refresh_token: nil,
      spotify_expires_at: nil
    )

    render json: { message: 'Spotify account disconnected successfully' }
  end

  def status
    connected = current_user.spotify_access_token.present?
    render json: { 
      connected: connected,
      expires_at: current_user.spotify_expires_at
    }
  end

  private

  def exchange_code_for_token(auth_code)
    # Use base_url but ensure it matches your Spotify app settings
    redirect_uri = "#{request.base_url}/auth/spotify/callback"
    puts "DEBUG: Redirect URI being used: #{redirect_uri}"
    
    response = HTTParty.post(
      'https://accounts.spotify.com/api/token',
      body: {
        grant_type: 'authorization_code',
        code: auth_code,
        redirect_uri: redirect_uri,
        client_id: ENV['SPOTIFY_CLIENT_ID'],
        client_secret: ENV['SPOTIFY_CLIENT_SECRET']
      },
      headers: {
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    )

    if response.success?
      {
        access_token: response['access_token'],
        refresh_token: response['refresh_token'],
        expires_in: response['expires_in']
      }
    else
      { error: "Failed to exchange code for token: #{response.body}" }
    end
  end
end