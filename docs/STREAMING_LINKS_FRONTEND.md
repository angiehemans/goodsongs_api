# Streaming Links - Frontend Implementation Guide

## Overview

Tracks now include links to streaming platforms (Spotify, Apple Music, etc.) so users can easily listen to reviewed songs. Users can set a preferred platform to show only that link when available.

---

## Endpoints with Streaming Links

- `GET /api/v1/fan_dashboard` - includes `track` with streaming links in `recent_reviews` and `following_feed_preview`
- `GET /reviews/:id` - includes `track` with streaming links
- `GET /api/v1/scrobbles` - includes `track` with streaming links
- `GET /users/:username` - includes `track` with streaming links in reviews

---

## Track Streaming Links

Tracks in reviews and scrobbles now include two new fields:

```json
{
  "track": {
    "id": "uuid",
    "name": "Karma Police",
    "streaming_links": {
      "spotify": "https://open.spotify.com/track/...",
      "appleMusic": "https://music.apple.com/us/album/...",
      "youtubeMusic": "https://music.youtube.com/watch?v=...",
      "tidal": "https://tidal.com/track/...",
      "amazonMusic": "https://music.amazon.com/albums/...",
      "deezer": "https://www.deezer.com/track/...",
      "soundcloud": "https://soundcloud.com/...",
      "bandcamp": "https://artist.bandcamp.com/track/..."
    },
    "songlink_url": "https://song.link/...",
    "songlink_search_url": "https://www.google.com/search?q=Radiohead%20Karma%20Police"
  }
}
```

### Notes

- `streaming_links` is an object containing only the platforms where the track is available (not all platforms will be present)
- `streaming_links` will be `{}` (empty object) if:
  - Links haven't been fetched yet
  - Track wasn't found on any platform
- `songlink_url` is a direct universal link (when ISRC lookup succeeded)
- `songlink_search_url` is a Google search fallback URL (always available) - use when `streaming_links` is empty
- Links are fetched asynchronously after track creation

### Fan Dashboard Example

`GET /api/v1/fan_dashboard` response includes:

```json
{
  "profile": {
    "preferred_streaming_platform": "spotify",
    ...
  },
  "recent_reviews": [
    {
      "id": 123,
      "song_name": "Karma Police",
      "band_name": "Radiohead",
      "track": {
        "id": "uuid",
        "name": "Karma Police",
        "streaming_links": {
          "spotify": "https://open.spotify.com/track/..."
        },
        "songlink_url": "https://song.link/...",
        "songlink_search_url": "https://www.google.com/search?q=Radiohead%20Karma%20Police"
      },
      ...
    }
  ],
  "following_feed_preview": [
    {
      "id": 456,
      "song_name": "Wretched and Unwanted",
      "track": {
        "id": "uuid",
        "name": "Wretched and Unwanted",
        "streaming_links": {},
        "songlink_url": null,
        "songlink_search_url": "https://www.google.com/search?q=The%20New%20Trust%20Wretched%20and%20Unwanted%20spotify%20OR%20apple%20music"
      },
      ...
    }
  ]
}
```

---

## User Preferred Platform

### Reading Preference

`GET /profile` now includes:

```json
{
  "preferred_streaming_platform": "spotify"
}
```

Value will be `null` if no preference is set.

### Setting Preference

`PATCH /profile`

```json
{
  "preferred_streaming_platform": "spotify"
}
```

**Valid values:** `spotify`, `appleMusic`, `youtubeMusic`, `tidal`, `amazonMusic`, `deezer`, `soundcloud`, `bandcamp`

Set to `null` to clear preference.

---

## Frontend Display Logic

```typescript
function getStreamingLink(track, userPreference) {
  const links = track.streaming_links || {};
  const hasLinks = Object.keys(links).length > 0;

  // No direct links available - use search fallback
  if (!hasLinks) {
    return {
      type: 'search',
      searchUrl: track.songlink_search_url
    };
  }

  // User has a preference and it's available
  if (userPreference && links[userPreference]) {
    return {
      type: 'preferred',
      platform: userPreference,
      url: links[userPreference]
    };
  }

  // User has preference but it's not available - show all
  if (userPreference && !links[userPreference]) {
    return {
      type: 'fallback',
      links: links,
      songlink_url: track.songlink_url
    };
  }

  // No preference set - show all or songlink
  return {
    type: 'all',
    links: links,
    songlink_url: track.songlink_url
  };
}
```

### UI Suggestions

| Scenario | Display |
|----------|---------|
| No direct links (`type: 'search'`) | "Search for song" button → opens `songlink_search_url` (Google search) |
| Preferred platform available (`type: 'preferred'`) | Single button: "Listen on Spotify" |
| Preferred platform NOT available (`type: 'fallback'`) | Show all available platforms or songlink |
| No preference set (`type: 'all'`) | Show songlink button or dropdown of all platforms |

---

## Platform Display Names & Icons

```typescript
const PLATFORMS = {
  spotify: { name: 'Spotify', icon: 'spotify-icon' },
  appleMusic: { name: 'Apple Music', icon: 'apple-music-icon' },
  youtubeMusic: { name: 'YouTube Music', icon: 'youtube-music-icon' },
  tidal: { name: 'Tidal', icon: 'tidal-icon' },
  amazonMusic: { name: 'Amazon Music', icon: 'amazon-music-icon' },
  deezer: { name: 'Deezer', icon: 'deezer-icon' },
  soundcloud: { name: 'SoundCloud', icon: 'soundcloud-icon' },
  bandcamp: { name: 'Bandcamp', icon: 'bandcamp-icon' }
};
```

---

## Settings UI

Add a "Preferred Streaming Platform" dropdown in user settings:

- Options: Spotify, Apple Music, YouTube Music, Tidal, Amazon Music, Deezer, SoundCloud, Bandcamp, None
- Save via `PATCH /profile` with `preferred_streaming_platform`
- "None" sends `null` to show all available platforms
