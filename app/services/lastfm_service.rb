class LastfmService
  include HTTParty
  base_uri 'https://ws.audioscrobbler.com/2.0'

  def initialize(user)
    @user = user
    @username = user.lastfm_username
  end

  def recently_played(limit: 20)
    return { error: 'No Last.fm username connected' } unless @username.present?

    response = self.class.get('/', query: {
      method: 'user.getRecentTracks',
      user: @username,
      api_key: api_key,
      format: 'json',
      limit: limit,
      extended: 1
    })

    if response.success?
      format_recently_played_response(response.parsed_response)
    else
      handle_api_error(response)
    end
  rescue StandardError => e
    Rails.logger.error("LastfmService error: #{e.message}")
    { error: "Last.fm API error: #{e.message}" }
  end

  def user_profile
    return { error: 'No Last.fm username connected' } unless @username.present?

    response = self.class.get('/', query: {
      method: 'user.getInfo',
      user: @username,
      api_key: api_key,
      format: 'json'
    })

    if response.success?
      format_user_profile(response.parsed_response)
    else
      handle_api_error(response)
    end
  rescue StandardError => e
    Rails.logger.error("LastfmService error: #{e.message}")
    { error: "Last.fm API error: #{e.message}" }
  end

  private

  def api_key
    ENV['LASTFM_API_KEY']
  end

  def format_recently_played_response(data)
    recent_tracks = data.dig('recenttracks', 'track')
    return { tracks: [] } unless recent_tracks.is_a?(Array)

    tracks = recent_tracks.map do |track|
      now_playing = track.dig('@attr', 'nowplaying') == 'true'
      artist_name = track.dig('artist', 'name') || track['artist'].to_s
      album_name = track.dig('album', '#text') || track['album'].to_s

      {
        name: track['name'],
        mbid: track['mbid'].presence,
        artists: [
          {
            name: artist_name,
            mbid: track.dig('artist', 'mbid').presence,
            lastfm_url: "https://www.last.fm/music/#{ERB::Util.url_encode(artist_name)}"
          }
        ],
        album: {
          name: album_name,
          mbid: track.dig('album', 'mbid').presence,
          images: format_images(track['image'])
        },
        lastfm_url: track['url'],
        played_at: now_playing ? nil : parse_timestamp(track.dig('date', 'uts')),
        now_playing: now_playing,
        loved: track['loved'] == '1'
      }
    end

    { tracks: tracks }
  end

  def format_user_profile(data)
    user = data['user']
    return { error: 'User not found' } unless user

    {
      name: user['name'],
      realname: user['realname'],
      url: user['url'],
      country: user['country'],
      playcount: user['playcount'].to_i,
      registered: user.dig('registered', 'unixtime')&.to_i,
      images: format_images(user['image'])
    }
  end

  def format_images(images)
    return [] unless images.is_a?(Array)

    images.filter_map do |img|
      next unless img['#text'].present?
      {
        url: img['#text'],
        size: img['size']
      }
    end
  end

  def parse_timestamp(uts)
    return nil unless uts.present?
    Time.at(uts.to_i).iso8601
  end

  def handle_api_error(response)
    parsed = response.parsed_response
    error_code = parsed['error']
    error_message = parsed['message']

    case error_code
    when 6
      { error: 'Last.fm user not found' }
    when 17
      { error: 'User profile is private' }
    when 26
      { error: 'API key suspended' }
    when 29
      { error: 'Rate limit exceeded. Please try again later.' }
    else
      { error: "Last.fm API error: #{error_message || response.code}" }
    end
  end
end
