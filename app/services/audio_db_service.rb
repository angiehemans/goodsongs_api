# frozen_string_literal: true

# Service for interacting with TheAudioDB API
# https://www.theaudiodb.com/free_music_api
class AudioDbService
  include HTTParty
  base_uri 'https://www.theaudiodb.com/api/v1/json'

  # Rate limit: max 2 calls per second
  RATE_LIMIT_DELAY = 0.5

  class << self
    # Search for an artist by name
    def search_artist(name)
      return nil if name.blank?

      response = rate_limited_get("/#{api_key}/search.php", query: { s: name })
      return nil unless response.success?

      artists = response.parsed_response['artists']
      return nil unless artists.is_a?(Array) && artists.any?

      format_artist(artists.first)
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.search_artist error: #{e.message}")
      nil
    end

    # Search for an album by artist and album name
    def search_album(artist:, album:)
      return nil if artist.blank? || album.blank?

      response = rate_limited_get("/#{api_key}/searchalbum.php", query: { s: artist, a: album })
      return nil unless response.success?

      albums = response.parsed_response['album']
      return nil unless albums.is_a?(Array) && albums.any?

      format_album(albums.first)
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.search_album error: #{e.message}")
      nil
    end

    # Search for a track by artist and track name
    # Returns a single best match (for backwards compatibility)
    def search_track(artist:, track:)
      results = search_tracks(artist: artist, track: track, limit: 1)
      results&.first
    end

    # Search for tracks - returns multiple matches
    # AudioDB searchtrack endpoint requires both artist and track
    def search_tracks(artist:, track:, limit: 10)
      return [] if track.blank? || artist.blank?

      response = rate_limited_get("/#{api_key}/searchtrack.php", query: { s: artist, t: track })
      return [] unless response.success?

      tracks = response.parsed_response['track']
      return [] unless tracks.is_a?(Array) && tracks.any?

      tracks.first(limit).map { |t| format_track(t) }.compact
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.search_tracks error: #{e.message}")
      []
    end

    # Get artist by TheAudioDB ID
    def get_artist(artist_id)
      return nil if artist_id.blank?

      response = rate_limited_get("/#{api_key}/artist.php", query: { i: artist_id })
      return nil unless response.success?

      artists = response.parsed_response['artists']
      return nil unless artists.is_a?(Array) && artists.any?

      format_artist(artists.first)
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_artist error: #{e.message}")
      nil
    end

    # Get artist by MusicBrainz ID
    def get_artist_by_mbid(mbid)
      return nil if mbid.blank?

      response = rate_limited_get("/#{api_key}/artist-mb.php", query: { i: mbid })
      return nil unless response.success?

      artists = response.parsed_response['artists']
      return nil unless artists.is_a?(Array) && artists.any?

      format_artist(artists.first)
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_artist_by_mbid error: #{e.message}")
      nil
    end

    # Get album by TheAudioDB ID
    def get_album(album_id)
      return nil if album_id.blank?

      response = rate_limited_get("/#{api_key}/album.php", query: { m: album_id })
      return nil unless response.success?

      albums = response.parsed_response['album']
      return nil unless albums.is_a?(Array) && albums.any?

      format_album(albums.first)
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_album error: #{e.message}")
      nil
    end

    # Get album by MusicBrainz release group ID
    def get_album_by_mbid(mbid)
      return nil if mbid.blank?

      response = rate_limited_get("/#{api_key}/album-mb.php", query: { i: mbid })
      return nil unless response.success?

      albums = response.parsed_response['album']
      return nil unless albums.is_a?(Array) && albums.any?

      format_album(albums.first)
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_album_by_mbid error: #{e.message}")
      nil
    end

    # Get all albums for an artist
    def get_artist_albums(artist_id)
      return [] if artist_id.blank?

      response = rate_limited_get("/#{api_key}/album.php", query: { i: artist_id })
      return [] unless response.success?

      albums = response.parsed_response['album']
      return [] unless albums.is_a?(Array)

      albums.map { |album| format_album(album) }
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_artist_albums error: #{e.message}")
      []
    end

    # Get tracks for an album
    def get_album_tracks(album_id)
      return [] if album_id.blank?

      response = rate_limited_get("/#{api_key}/track.php", query: { m: album_id })
      return [] unless response.success?

      tracks = response.parsed_response['track']
      return [] unless tracks.is_a?(Array)

      tracks.map { |track| format_track(track) }
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_album_tracks error: #{e.message}")
      []
    end

    # Get top 10 tracks for an artist
    def get_artist_top_tracks(artist_name)
      return [] if artist_name.blank?

      response = rate_limited_get("/#{api_key}/track-top10.php", query: { s: artist_name })
      return [] unless response.success?

      tracks = response.parsed_response['track']
      return [] unless tracks.is_a?(Array)

      tracks.map { |track| format_track(track) }
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_artist_top_tracks error: #{e.message}")
      []
    end

    # Get music videos for an artist
    def get_artist_music_videos(artist_id)
      return [] if artist_id.blank?

      response = rate_limited_get("/#{api_key}/mvid.php", query: { i: artist_id })
      return [] unless response.success?

      videos = response.parsed_response['mvids']
      return [] unless videos.is_a?(Array)

      videos.map do |video|
        {
          id: video['idTrack'],
          track_name: video['strTrack'],
          music_video_url: video['strMusicVid'],
          description: video['strDescriptionEN']
        }
      end
    rescue StandardError => e
      Rails.logger.warn("AudioDbService.get_artist_music_videos error: #{e.message}")
      []
    end

    private

    def api_key
      # Use environment variable if set, otherwise use free API key
      ENV.fetch('AUDIODB_API_KEY', '2')
    end

    def rate_limited_get(path, options = {})
      sleep(RATE_LIMIT_DELAY)
      self.get(path, options)
    end

    def format_artist(artist)
      return nil unless artist

      {
        id: artist['idArtist'],
        name: artist['strArtist'],
        musicbrainz_id: artist['strMusicBrainzID'],
        biography: artist['strBiographyEN'],
        country: artist['strCountry'],
        formed_year: artist['intFormedYear'],
        disbanded_year: artist['intDiedYear'],
        genre: artist['strGenre'],
        style: artist['strStyle'],
        mood: artist['strMood'],
        # Images
        artist_thumb: artist['strArtistThumb'],
        artist_logo: artist['strArtistLogo'],
        artist_fanart: artist['strArtistFanart'],
        artist_fanart2: artist['strArtistFanart2'],
        artist_fanart3: artist['strArtistFanart3'],
        artist_banner: artist['strArtistBanner'],
        artist_wide_thumb: artist['strArtistWideThumb'],
        artist_clearart: artist['strArtistClearart'],
        # Social/Links
        website: artist['strWebsite'],
        facebook: artist['strFacebook'],
        twitter: artist['strTwitter'],
        lastfm: artist['strLastFMChart']
      }
    end

    def format_album(album)
      return nil unless album

      {
        id: album['idAlbum'],
        artist_id: album['idArtist'],
        name: album['strAlbum'],
        artist_name: album['strArtist'],
        musicbrainz_id: album['strMusicBrainzID'],
        release_year: album['intYearReleased'],
        genre: album['strGenre'],
        style: album['strStyle'],
        mood: album['strMood'],
        description: album['strDescriptionEN'],
        # Images - these are the key ones for artwork
        album_thumb: album['strAlbumThumb'],
        album_thumb_hq: album['strAlbumThumbHQ'],
        album_cdart: album['strAlbumCDart'],
        album_spine: album['strAlbumSpine'],
        album_3d_case: album['strAlbum3DCase'],
        album_3d_flat: album['strAlbum3DFlat'],
        album_3d_face: album['strAlbum3DFace'],
        album_3d_thumb: album['strAlbum3DThumb'],
        # Metadata
        label: album['strLabel'],
        format: album['strReleaseFormat'],
        sales: album['intSales'],
        score: album['intScore'],
        score_votes: album['intScoreVotes']
      }
    end

    def format_track(track)
      return nil unless track

      {
        id: track['idTrack'],
        album_id: track['idAlbum'],
        artist_id: track['idArtist'],
        name: track['strTrack'],
        artist_name: track['strArtist'],
        album_name: track['strAlbum'],
        musicbrainz_id: track['strMusicBrainzID'],
        duration_ms: track['intDuration']&.to_i,
        track_number: track['intTrackNumber']&.to_i,
        genre: track['strGenre'],
        style: track['strStyle'],
        mood: track['strMood'],
        description: track['strDescriptionEN'],
        # Media
        music_video_url: track['strMusicVid'],
        track_thumb: track['strTrackThumb'],
        # Lyrics
        lyrics: track['strTrackLyrics']
      }
    end
  end
end
