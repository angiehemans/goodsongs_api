class LastfmController < ApplicationController
  include ResourceController

  skip_before_action :require_onboarding_completed
  before_action :authenticate_request

  def connect
    username = params[:username]&.strip

    if username.blank?
      render_error('Last.fm username is required', :bad_request)
      return
    end

    # Validate the username exists on Last.fm
    validation_result = validate_lastfm_username(username)

    if validation_result[:error]
      render_error(validation_result[:error], :bad_request)
      return
    end

    current_user.update!(lastfm_username: username)

    json_response({
      message: 'Last.fm account connected successfully',
      username: username,
      profile: validation_result[:profile]
    })
  end

  def disconnect
    current_user.update!(lastfm_username: nil)

    json_response({ message: 'Last.fm account disconnected successfully' })
  end

  def status
    connected = current_user.lastfm_username.present?

    response_data = {
      connected: connected,
      username: current_user.lastfm_username
    }

    if connected
      profile = LastfmService.new(current_user).user_profile
      response_data[:profile] = profile unless profile[:error]
    end

    json_response(response_data)
  end

  def search_artist
    query = params[:query]&.strip

    if query.blank?
      render_error('Search query is required', :bad_request)
      return
    end

    results = LastfmArtistService.search_artist(query, limit: params[:limit]&.to_i || 10)

    json_response({ artists: results })
  end

  private

  def validate_lastfm_username(username)
    # Create a simple object that responds to lastfm_username
    user_stub = Struct.new(:lastfm_username).new(username)
    service = LastfmService.new(user_stub)
    profile = service.user_profile

    if profile[:error]
      { error: profile[:error] }
    else
      { profile: profile }
    end
  end
end
