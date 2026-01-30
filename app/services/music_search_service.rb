# frozen_string_literal: true

class MusicSearchService
  DEFAULT_LIMIT = 10

  class << self
    # Unified entry point
    def search(query: nil, type: nil, track: nil, artist: nil, album: nil, limit: DEFAULT_LIMIT)
      case type&.to_s
      when 'artist'
        { artists: search_artists(query || artist, limit: limit) }
      when 'track'
        { tracks: search_tracks(track: query || track, artist: artist, limit: limit) }
      when 'album'
        { albums: search_albums(album: query || album, artist: artist, limit: limit) }
      else
        # Search all three types
        q = query || track || artist || album
        {
          artists: search_artists(q, limit: limit),
          tracks: search_tracks(track: q, artist: artist, limit: limit),
          albums: search_albums(album: q, artist: artist, limit: limit)
        }
      end
    end

    # Trigram search on bands.name + band_aliases.name, merged & deduped
    def search_artists(query, limit: DEFAULT_LIMIT)
      return [] if query.blank?

      # Search bands by name
      band_results = Band.search_by_name(query).limit(limit)

      # Search band aliases and get their bands
      alias_band_ids = BandAlias.search_by_name(query).limit(limit).pluck(:band_id)
      alias_bands = Band.where(id: alias_band_ids)

      # Merge and deduplicate, preferring the direct match
      seen_ids = Set.new
      results = []

      band_results.each do |band|
        next if seen_ids.include?(band.id)
        seen_ids.add(band.id)
        results << format_artist(band, similarity_score(band.name, query))
      end

      alias_bands.each do |band|
        next if seen_ids.include?(band.id)
        seen_ids.add(band.id)
        # Score based on best alias match
        best_alias = band.band_aliases.select { |a| trigram_similar?(a.name, query) }
                         .max_by { |a| similarity_score(a.name, query) }
        score = best_alias ? similarity_score(best_alias.name, query) : 0.0
        results << format_artist(band, score)
      end

      results.sort_by { |r| -r[:similarity] }.first(limit)
    end

    # Trigram search on tracks, optionally filtered by artist
    def search_tracks(track:, artist: nil, limit: DEFAULT_LIMIT)
      return [] if track.blank?

      if artist.present?
        # JOIN bands for combined scoring
        tracks = Track.joins(:band)
                      .where("tracks.name % ?", track)
                      .where("bands.name % ?", artist)
                      .select(
                        "tracks.*",
                        Arel.sql("(0.6 * similarity(tracks.name, #{Track.connection.quote(track)}) + 0.4 * similarity(bands.name, #{Band.connection.quote(artist)})) AS combined_score")
                      )
                      .order(Arel.sql("combined_score DESC"))
                      .limit(limit)
                      .includes(:band, :album)
      else
        tracks = Track.search_by_name(track).limit(limit).includes(:band, :album)
      end

      tracks.map do |t|
        score = if artist.present? && t.respond_to?(:combined_score)
                  t.combined_score.to_f
                else
                  similarity_score(t.name, track)
                end
        format_track(t, score)
      end
    end

    # Trigram search on albums, optionally filtered by artist
    def search_albums(album:, artist: nil, limit: DEFAULT_LIMIT)
      return [] if album.blank?

      if artist.present?
        albums = Album.joins(:band)
                      .where("albums.name % ?", album)
                      .where("bands.name % ?", artist)
                      .select(
                        "albums.*",
                        Arel.sql("(0.6 * similarity(albums.name, #{Album.connection.quote(album)}) + 0.4 * similarity(bands.name, #{Band.connection.quote(artist)})) AS combined_score")
                      )
                      .order(Arel.sql("combined_score DESC"))
                      .limit(limit)
                      .includes(:band)
      else
        albums = Album.search_by_name(album).limit(limit).includes(:band)
      end

      albums.map do |a|
        score = if artist.present? && a.respond_to?(:combined_score)
                  a.combined_score.to_f
                else
                  similarity_score(a.name, album)
                end
        format_album(a, score)
      end
    end

    private

    def format_artist(band, score)
      {
        type: 'artist',
        id: band.id,
        name: band.name,
        similarity: score.round(3),
        image_url: band.artist_image_url,
        musicbrainz_id: band.musicbrainz_id,
        source: band.source
      }
    end

    def format_track(track, score)
      {
        type: 'track',
        id: track.id,
        name: track.name,
        similarity: score.round(3),
        artist: track.band ? {
          id: track.band.id,
          name: track.band.name,
          image_url: track.band.artist_image_url
        } : nil,
        album: track.album ? {
          id: track.album.id,
          name: track.album.name,
          cover_art_url: track.album.cover_art_url
        } : nil,
        source: track.source
      }
    end

    def format_album(album, score)
      {
        type: 'album',
        id: album.id,
        name: album.name,
        similarity: score.round(3),
        artist: album.band ? {
          id: album.band.id,
          name: album.band.name,
          image_url: album.band.artist_image_url
        } : nil,
        cover_art_url: album.cover_art_url,
        release_date: album.release_date,
        source: album.source
      }
    end

    def similarity_score(text, query)
      Band.connection.select_value(
        "SELECT similarity(#{Band.connection.quote(text)}, #{Band.connection.quote(query)})"
      ).to_f
    end

    def trigram_similar?(text, query)
      Band.connection.select_value(
        "SELECT #{Band.connection.quote(text)} % #{Band.connection.quote(query)}"
      )
    end
  end
end
