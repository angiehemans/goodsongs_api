# Last.fm Integration Development Plan

## Overview

[Last.fm](https://www.last.fm/api) offers a free, well-documented API that tracks listening history ("scrobbles") across multiple music services. Unlike Spotify or Apple Music, Last.fm aggregates listening data from various sources - users can connect their Spotify, Apple Music, or other services to Last.fm.

## Key Advantages Over Other Services

| Aspect | Spotify | Apple Music | Last.fm |
|--------|---------|-------------|---------|
| Cost | Free | $99/year | **Free** |
| Auth Complexity | OAuth 2.0 | MusicKit + JWT | **Simple web auth** |
| Session Expiry | Needs refresh | ~6 months | **Infinite (until revoked)** |
| User Requirement | Spotify account | Apple Music subscription | **Free Last.fm account** |
| Cross-platform | Spotify only | Apple Music only | **Aggregates all services** |
| Artist Images | ✅ Reliable | ✅ Reliable | ⚠️ Often placeholder images |

## How Last.fm Works

1. Users create a free Last.fm account
2. Users connect their music services (Spotify, Apple Music, etc.) to Last.fm
3. Last.fm tracks all their listening ("scrobbles") in one place
4. Your app can query their listening history via the API

## Prerequisites

1. Create a [Last.fm API account](https://www.last.fm/api/account/create) (free)
2. Get your **API Key** and **Shared Secret**

## Implementation Plan

### Phase 1: Backend Setup

#### 1.1 Add Last.fm credentials to environment
```ruby
# .env
LASTFM_API_KEY=your_api_key
LASTFM_SHARED_SECRET=your_shared_secret
```

#### 1.2 Add ruby-lastfm gem
```ruby
# Gemfile
gem 'lastfm'
```

#### 1.3 Database migration
```ruby
# Add to users table
add_column :users, :lastfm_session_key, :string
add_column :users, :lastfm_username, :string
```

#### 1.4 Create LastfmService
```ruby
# app/services/lastfm_service.rb
class LastfmService
  def initialize(user)
    @user = user
    @client = Lastfm.new(ENV['LASTFM_API_KEY'], ENV['LASTFM_SHARED_SECRET'])
    @client.session = user.lastfm_session_key
  end

  def recently_played(limit: 20)
    # GET user.getRecentTracks
    # Returns tracks with: name, artist, album, image, date, now_playing flag
    tracks = @client.user.get_recent_tracks(
      user: @user.lastfm_username,
      limit: limit,
      extended: 1
    )
    format_tracks(tracks)
  end

  private

  def format_tracks(tracks)
    tracks.map do |track|
      {
        name: track['name'],
        artists: [{
          name: track['artist']['name'],
          # Last.fm doesn't provide artist Spotify URLs, but we can search
          lastfm_url: track['artist']['url']
        }],
        album: {
          name: track['album']['#text'],
          images: track['image']
        },
        played_at: track['date']['uts'],
        now_playing: track['@attr']&.dig('nowplaying') == 'true'
      }
    end
  end
end
```

#### 1.5 Create LastfmController
```ruby
# app/controllers/lastfm_controller.rb
class LastfmController < ApplicationController
  before_action :authenticate_request

  # GET /lastfm/connect - Redirect to Last.fm auth
  def connect
    callback_url = "#{request.base_url}/auth/lastfm/callback"
    auth_url = "https://www.last.fm/api/auth/?api_key=#{ENV['LASTFM_API_KEY']}&cb=#{CGI.escape(callback_url)}"

    if request.format.json?
      json_response({ auth_url: auth_url })
    else
      redirect_to auth_url, allow_other_host: true
    end
  end

  # GET /auth/lastfm/callback - Handle callback from Last.fm
  def callback
    token = params[:token]

    # Exchange token for session key
    client = Lastfm.new(ENV['LASTFM_API_KEY'], ENV['LASTFM_SHARED_SECRET'])
    session_info = client.auth.get_session(token: token)

    current_user.update!(
      lastfm_session_key: session_info['key'],
      lastfm_username: session_info['name']
    )

    redirect_to "#{ENV['FRONTEND_URL']}/dashboard?lastfm=connected", allow_other_host: true
  end

  # DELETE /lastfm/disconnect
  def disconnect
    current_user.update!(
      lastfm_session_key: nil,
      lastfm_username: nil
    )
    json_response({ message: 'Last.fm disconnected' })
  end

  # GET /lastfm/status
  def status
    json_response({
      connected: current_user.lastfm_session_key.present?,
      username: current_user.lastfm_username
    })
  end

  # GET /lastfm/recently-played
  def recently_played
    service = LastfmService.new(current_user)
    tracks = service.recently_played(limit: params[:limit] || 20)
    json_response({ tracks: tracks })
  end
end
```

#### 1.6 Add routes
```ruby
# config/routes.rb
get '/lastfm/connect', to: 'lastfm#connect'
get '/auth/lastfm/callback', to: 'lastfm#callback'
delete '/lastfm/disconnect', to: 'lastfm#disconnect'
get '/lastfm/status', to: 'lastfm#status'
get '/lastfm/recently-played', to: 'lastfm#recently_played'
```

### Phase 2: Artist Lookup (for Band Images)

Last.fm artist images are often placeholder images, so we have two options:

#### Option A: Use Last.fm artist data anyway
```ruby
# app/services/lastfm_artist_service.rb
class LastfmArtistService
  def self.fetch_artist_image(artist_name)
    client = Lastfm.new(ENV['LASTFM_API_KEY'], ENV['LASTFM_SHARED_SECRET'])
    info = client.artist.get_info(artist: artist_name)

    # Get largest image (extralarge or mega)
    images = info['image']
    large_image = images.find { |img| img['size'] == 'extralarge' }
    image_url = large_image&.dig('#text')

    # Check if it's not the placeholder
    return nil if image_url&.include?('2a96cbd8b46e442fc41c2b86b821562f')
    image_url
  end
end
```

#### Option B: Search Spotify for artist image (recommended)
Since Last.fm images are unreliable, use the band name to search Spotify's API for the artist image:

```ruby
# app/services/spotify_artist_service.rb
# Add search method to existing service
def self.search_artist_image(artist_name)
  token = access_token
  return nil unless token

  response = get(
    "/search",
    query: { q: artist_name, type: 'artist', limit: 1 },
    headers: { 'Authorization' => "Bearer #{token}" }
  )

  return nil unless response.success?

  artist = response.dig('artists', 'items', 0)
  artist&.dig('images', 0, 'url')
end
```

### Phase 3: Frontend Integration

#### 3.1 Add Last.fm connection UI
Similar to Spotify connection - button that opens Last.fm auth in popup/redirect.

#### 3.2 Display recently played from Last.fm
```typescript
// Check which service is connected and fetch accordingly
const getRecentlyPlayed = async () => {
  const spotifyStatus = await api.getSpotifyStatus()
  const lastfmStatus = await api.getLastfmStatus()

  if (spotifyStatus.connected) {
    return api.getSpotifyRecentlyPlayed()
  } else if (lastfmStatus.connected) {
    return api.getLastfmRecentlyPlayed()
  }
  return null
}
```

### Phase 4: Unified Music Service

```ruby
# app/services/music_service.rb
class MusicService
  def self.for_user(user)
    if user.spotify_access_token.present?
      SpotifyService.new(user)
    elsif user.lastfm_session_key.present?
      LastfmService.new(user)
    elsif user.apple_music_user_token.present?
      AppleMusicService.new(user)
    end
  end
end
```

## Files to Create/Modify

### New Files
| File | Purpose |
|------|---------|
| `app/services/lastfm_service.rb` | Last.fm API client |
| `app/controllers/lastfm_controller.rb` | API endpoints |
| `db/migrate/xxx_add_lastfm_to_users.rb` | User session storage |
| `config/initializers/lastfm.rb` | Optional gem configuration |

### Modified Files
| File | Changes |
|------|---------|
| `Gemfile` | Add `lastfm` gem |
| `config/routes.rb` | Add Last.fm routes |
| `app/models/user.rb` | Add `lastfm_connected?` method |
| `app/services/spotify_artist_service.rb` | Add artist search method |
| `.env` | Last.fm credentials |
| `.kamal/secrets` | Production credentials |

## Authentication Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Frontend  │     │   Backend   │     │   Last.fm   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ Click "Connect"   │                   │
       ├──────────────────>│                   │
       │                   │                   │
       │   Auth URL        │                   │
       │<──────────────────┤                   │
       │                   │                   │
       │ Redirect to Last.fm                   │
       ├──────────────────────────────────────>│
       │                   │                   │
       │                   │   User grants     │
       │                   │   permission      │
       │                   │                   │
       │ Callback with token                   │
       │<──────────────────────────────────────┤
       │                   │                   │
       │ Token             │                   │
       ├──────────────────>│                   │
       │                   │                   │
       │                   │ Exchange for      │
       │                   │ session key       │
       │                   ├──────────────────>│
       │                   │                   │
       │                   │ Session key       │
       │                   │ (never expires)   │
       │                   │<──────────────────┤
       │                   │                   │
       │ Success redirect  │                   │
       │<──────────────────┤                   │
       │                   │                   │
```

## Limitations & Considerations

1. **Artist images unreliable** - Often returns placeholder images; recommend using Spotify search as fallback
2. **No direct song links** - Last.fm provides Last.fm URLs, not streaming service URLs
3. **Scrobble delay** - Recent tracks may have slight delay depending on user's scrobbling setup
4. **Username required** - API calls need the Last.fm username, stored during auth

## Estimated Effort

- Phase 1 (Backend): 2-3 hours
- Phase 2 (Artist Lookup): 1 hour
- Phase 3 (Frontend): 1-2 hours
- Phase 4 (Unified Service): 1 hour

**Total: 5-7 hours** (significantly less than Apple Music)

## Resources

- [Last.fm API - user.getRecentTracks](https://www.last.fm/api/show/user.getRecentTracks)
- [Last.fm Web Authentication](https://www.last.fm/api/webauth)
- [Last.fm Authentication Overview](https://www.last.fm/api/authentication)
- [ruby-lastfm gem](https://github.com/youpy/ruby-lastfm)
- [artist.getInfo API](https://www.last.fm/api/show/artist.getInfo)
