# Apple Music Integration Development Plan

## Overview

Apple Music offers an official API ([MusicKit](https://developer.apple.com/musickit/)) that includes a [`/me/recent/played/tracks`](https://developer.apple.com/documentation/applemusicapi/history) endpoint for recently played tracks - similar to Spotify's functionality.

## Key Differences from Spotify

| Aspect | Spotify | Apple Music |
|--------|---------|-------------|
| Auth Flow | OAuth 2.0 with refresh tokens | MusicKit JS popup + Music User Token |
| Developer Token | Client ID/Secret | JWT signed with ES256 private key |
| Token Refresh | Automatic via refresh token | Manual - expires after ~6 months |
| Cost | Free | Requires Apple Developer Program ($99/year) |
| User Requirement | Spotify account (free or premium) | Apple Music subscription |

## Prerequisites

1. **Apple Developer Program membership** ($99/year)
2. Create a **MusicKit Identifier** in Apple Developer portal
3. Generate a **MusicKit private key** (.p8 file)
4. Note your **Team ID** and **Key ID**

## Implementation Plan

### Phase 1: Backend Setup

#### 1.1 Add Apple Music credentials to environment
```ruby
# .env
APPLE_MUSIC_TEAM_ID=your_team_id
APPLE_MUSIC_KEY_ID=your_key_id
APPLE_MUSIC_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
```

#### 1.2 Create AppleMusicTokenService
Generate JWT developer tokens using ES256 algorithm (requires `jwt` gem).

```ruby
# app/services/apple_music_token_service.rb
class AppleMusicTokenService
  def self.developer_token
    # Generate JWT with:
    # - Header: alg: ES256, kid: KEY_ID
    # - Payload: iss: TEAM_ID, iat: now, exp: now + 6 months
    # - Sign with private key
  end
end
```

#### 1.3 Create AppleMusicService
Handle API calls to Apple Music API for recently played tracks.

```ruby
# app/services/apple_music_service.rb
class AppleMusicService
  BASE_URI = 'https://api.music.apple.com/v1'

  def recently_played(limit: 20)
    # GET /me/recent/played/tracks
    # Headers: Authorization: Bearer {developer_token}
    #          Music-User-Token: {user_token}
  end
end
```

#### 1.4 Database migration
```ruby
# Add to users table
add_column :users, :apple_music_user_token, :text
add_column :users, :apple_music_connected_at, :datetime
```

#### 1.5 Create AppleMusicController
```ruby
# app/controllers/apple_music_controller.rb
class AppleMusicController < ApplicationController
  def developer_token    # GET /apple-music/token - returns JWT for MusicKit JS
  def save_user_token    # POST /apple-music/connect - saves user token from frontend
  def disconnect         # DELETE /apple-music/disconnect
  def status             # GET /apple-music/status
  def recently_played    # GET /apple-music/recently-played
end
```

### Phase 2: Frontend Integration

#### 2.1 Load MusicKit JS
```html
<script src="https://js-cdn.music.apple.com/musickit/v3/musickit.js"></script>
```

#### 2.2 Initialize and authorize
```javascript
// 1. Fetch developer token from backend
const devToken = await fetch('/apple-music/token').then(r => r.json())

// 2. Configure MusicKit
await MusicKit.configure({
  developerToken: devToken.token,
  app: { name: 'GoodSongs', build: '1.0' }
})

// 3. Authorize user (opens Apple popup)
const music = MusicKit.getInstance()
const userToken = await music.authorize()

// 4. Send user token to backend
await fetch('/apple-music/connect', {
  method: 'POST',
  body: JSON.stringify({ user_token: userToken })
})
```

### Phase 3: Artist Image Integration

#### 3.1 Update SpotifyArtistService to support Apple Music
- Apple Music API returns artist images via `/v1/catalog/{storefront}/artists/{id}`
- Update `BandSerializer` to check for Apple Music artist URLs

#### 3.2 Add apple_music_link to bands
```ruby
add_column :bands, :apple_music_image_url, :string
```

### Phase 4: Unified Music Service

#### 4.1 Create abstraction layer
```ruby
# app/services/music_service.rb
class MusicService
  def self.for_user(user)
    if user.spotify_connected?
      SpotifyService.new(user)
    elsif user.apple_music_connected?
      AppleMusicService.new(user)
    end
  end

  def recently_played
    raise NotImplementedError
  end
end
```

## Files to Create/Modify

### New Files
| File | Purpose |
|------|---------|
| `app/services/apple_music_token_service.rb` | Generate developer JWT |
| `app/services/apple_music_service.rb` | Apple Music API client |
| `app/controllers/apple_music_controller.rb` | API endpoints |
| `db/migrate/xxx_add_apple_music_to_users.rb` | User token storage |
| `db/migrate/xxx_add_apple_music_image_to_bands.rb` | Artist image cache |

### Modified Files
| File | Changes |
|------|---------|
| `config/routes.rb` | Add Apple Music routes |
| `app/models/user.rb` | Add `apple_music_connected?` method |
| `app/serializers/band_serializer.rb` | Include Apple Music image fallback |
| `.env` | Apple Music credentials |
| `.kamal/secrets` | Production credentials |

## Limitations & Considerations

1. **$99/year cost** - Requires Apple Developer Program
2. **Token expiration** - Music User Tokens expire after ~6 months with no auto-refresh
3. **Subscription required** - Users need active Apple Music subscription
4. **No refresh token** - Unlike Spotify, users must re-authorize when token expires

## Estimated Effort

- Phase 1 (Backend): 4-6 hours
- Phase 2 (Frontend): 2-3 hours
- Phase 3 (Artist Images): 1-2 hours
- Phase 4 (Unified Service): 1-2 hours

## Resources

- [MusicKit - Apple Developer](https://developer.apple.com/musickit/)
- [User Authentication for MusicKit](https://developer.apple.com/documentation/applemusicapi/user-authentication-for-musickit)
- [History API Documentation](https://developer.apple.com/documentation/applemusicapi/history)
- [MusicKit Token Encoder](https://github.com/mkoehnke/musickit-token-encoder)
- [ruby-jwt gem](https://github.com/jwt/ruby-jwt)
