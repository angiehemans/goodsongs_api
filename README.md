# Good Songs API 🎵

A Ruby on Rails API for music reviews and recommendations. Users can create accounts, write detailed song reviews, and discover music through a community feed.

## Features

- **User Authentication**: JWT-based authentication system
- **Song Reviews**: Write reviews with ratings (1-3), liked aspects, and detailed text
- **Music Search**: Search for songs via MusicBrainz and Discogs APIs with cover art
- **Band Management**: Automatic band creation and organization
- **Review Feed**: Discover new music through community reviews
- **User Profiles**: Public user profiles showing all reviews
- **Multi-select Aspects**: Tag reviews with what you loved (Guitar, Vocals, Lyrics, etc.)

## Tech Stack

- **Ruby on Rails** 8.0.2 (API mode)
- **PostgreSQL** (database)
- **JWT** (authentication)
- **BCrypt** (password encryption)
- **Rack-CORS** (cross-origin requests)
- **MusicBrainz API** (music metadata and search)
- **Discogs API** (music search with cover art)
- **CoverArtArchive** (album artwork)
- **Last.fm API** (scrobbling)

## Prerequisites

- Ruby 3.x or higher
- PostgreSQL (we recommend [Postgres.app](https://postgresapp.com/) for macOS)
- Bundler gem

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd goodsongs_api
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Database Setup

#### Configure PostgreSQL

Make sure PostgreSQL is running. If using Postgres.app, note the port (usually 5445).

#### Update Database Configuration

Edit `config/database.yml` if needed to match your PostgreSQL setup:

```yaml
development:
  adapter: postgresql
  encoding: unicode
  pool: 5
  database: goodsongs_api_development
  host: localhost
  port: 5445 # Update if your PostgreSQL runs on a different port
```

#### Create and Setup Database

```bash
rails db:create
rails db:migrate
```

### 4. Start the Server

```bash
rails server
```

The API will be available at `http://localhost:3000`

## API Endpoints

### Authentication

- `POST /signup` - Create a new user account
- `POST /auth/login` - Login and get JWT token
- `GET /profile` - Get current user's profile (requires auth)

### Reviews

- `GET /reviews` - Get all reviews (requires auth)
- `POST /reviews` - Create a new review (requires auth)
- `GET /reviews/:id` - Get specific review (requires auth)
- `PUT /reviews/:id` - Update review (requires auth, owner only)
- `DELETE /reviews/:id` - Delete review (requires auth, owner only)

### Public Endpoints

- `GET /users/:username` - Get public user profile with reviews
- `GET /feed` - Get latest reviews feed (requires auth)

### Music Search (MusicBrainz)

- `GET /musicbrainz/search` - Search for songs/artists (requires auth)
  - Query params: `track`, `artist`, `q` (combined search), `limit`, `sort`, `official_only`
  - Sort options: `relevance`, `releases`, `date`, `original` (default)
- `GET /musicbrainz/recording/:mbid` - Get recording details with artwork (requires auth)

### Music Search (Discogs)

- `GET /discogs/search` - Search for releases (requires auth)
  - Query params: `track`, `artist`, `q` (combined search), `limit`
- `GET /discogs/master/:id` - Get master release with tracklist (requires auth)
- `GET /discogs/release/:id` - Get release with tracklist (requires auth)

### Health Check

- `GET /health` - API health check

## API Usage Examples

### Create a User

```bash
curl -X POST http://localhost:3000/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "musiclover",
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123"
  }'
```

### Login

```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

### Create a Review

```bash
curl -X POST http://localhost:3000/reviews \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "review": {
      "song_link": "https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh",
      "band_name": "The Beatles",
      "song_name": "Hey Jude",
      "artwork_url": "https://example.com/cover.jpg",
      "review_text": "Incredible song with amazing vocals and emotional depth!",
      "overall_rating": 3,
      "liked_aspects": ["Vocals", "Lyrics", "Melody"]
    }
  }'
```

### Get User Profile

```bash
curl http://localhost:3000/users/musiclover
```

### Search for Songs (MusicBrainz)

```bash
# Search by track name
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:3000/musicbrainz/search?track=Hey%20Jude&limit=5"

# Search by artist
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:3000/musicbrainz/search?artist=Beatles&limit=5"

# Combined search
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:3000/musicbrainz/search?q=Beatles&sort=original"
```

Response:
```json
{
  "results": [
    {
      "mbid": "recording-uuid",
      "song_name": "Hey Jude",
      "band_name": "The Beatles",
      "release_name": "Hey Jude / Revolution",
      "release_date": "1968-08-26",
      "artwork_url": "https://coverartarchive.org/release/xxx/front-500",
      "is_original_release": true
    }
  ]
}
```

### Search for Songs (Discogs)

```bash
# Search by track and artist
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:3000/discogs/search?track=Yellow&artist=Coldplay&limit=5"

# Get master release with tracklist
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:3000/discogs/master/31927"
```

Response (search):
```json
{
  "results": [
    {
      "id": 123456,
      "master_id": 123456,
      "type": "master",
      "song_name": null,
      "band_name": "Coldplay",
      "release_name": "Parachutes",
      "release_year": "2000",
      "artwork_url": "https://i.discogs.com/...",
      "genre": "Rock",
      "style": "Alternative Rock"
    }
  ]
}
```

Response (master with tracks):
```json
{
  "master": {
    "id": 123456,
    "title": "Parachutes",
    "artist": "Coldplay",
    "year": 2000,
    "cover_image": "https://i.discogs.com/..."
  },
  "tracks": [
    {
      "position": "1",
      "song_name": "Don't Panic",
      "band_name": "Coldplay",
      "release_name": "Parachutes",
      "artwork_url": "https://i.discogs.com/...",
      "prefill": {
        "song_name": "Don't Panic",
        "band_name": "Coldplay",
        "artwork_url": "https://i.discogs.com/..."
      }
    }
  ]
}
```

## Data Models

### User

- `username` (string, unique)
- `email` (string, unique)
- `password_digest` (encrypted)

### Review

- `song_link` (string) - Link to the song
- `band_name` (string) - Name of the band/artist
- `song_name` (string) - Title of the song
- `artwork_url` (string) - Cover art URL
- `review_text` (text) - Review content
- `overall_rating` (integer, 1-3) - Overall rating
- `liked_aspects` (text) - Comma-separated aspects
- `user_id` (foreign key)
- `band_id` (foreign key)

### Band

- `name` (string, unique) - Band/artist name

## Available Liked Aspects

When creating reviews, you can select from these aspects:

- Guitar
- Vocals
- Lyrics
- Drums
- Bass
- Production
- Melody
- Rhythm
- Energy
- Creativity

## Development

### Running Tests

```bash
bundle exec rspec
```

### Database Commands

```bash
# Reset database
rails db:drop db:create db:migrate

# Check migration status
rails db:migrate:status

# Rollback migration
rails db:rollback
```

### Rails Console

```bash
rails console
```

## CORS Configuration

The API is configured to accept requests from:

- `http://localhost:3000` (Rails default)
- `http://localhost:3001` (Common frontend port)

To add more origins, edit `config/initializers/cors.rb`.

## Environment Variables

Create a `.env` file (not tracked in git) for sensitive configuration:

```
JWT_SECRET_KEY=your_secret_key_here
DATABASE_URL=postgresql://user:password@localhost/goodsongs_api_development

# Last.fm API (for scrobbling)
LASTFM_API_KEY=your_lastfm_api_key

# Discogs API (for music search)
DISCOGS_CONSUMER_KEY=your_discogs_consumer_key
DISCOGS_CONSUMER_SECRET=your_discogs_consumer_secret
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`bundle exec rspec`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Common Issues

### PostgreSQL Connection Issues

- Ensure PostgreSQL is running
- Check the port in `database.yml` matches your PostgreSQL instance
- For Postgres.app users, the default port is usually 5445

### CORS Issues

- Make sure your frontend origin is listed in `config/initializers/cors.rb`
- Check browser console for specific CORS error messages

### Authentication Issues

- Ensure JWT token is included in Authorization header: `Bearer YOUR_TOKEN`
- Check token expiration and refresh as needed
