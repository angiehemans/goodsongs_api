# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      RATE_LIMIT_PER_MINUTE = 30
      DEFAULT_LIMIT = 10
      MAX_LIMIT = 25
      LOCAL_THRESHOLD = 3

      before_action :check_rate_limit

      # GET /api/v1/search
      def index
        q = params[:q]&.strip.presence
        track = params[:track]&.strip.presence
        artist = params[:artist]&.strip.presence
        album = params[:album]&.strip.presence
        type = params[:type]&.strip.presence
        limit = [[params[:limit]&.to_i || DEFAULT_LIMIT, MAX_LIMIT].min, 1].max

        unless q.present? || track.present? || artist.present? || album.present?
          return render_api_error(
            code: 'validation_failed',
            message: 'At least one of q, track, artist, or album is required',
            status: :bad_request
          )
        end

        if type.present? && !%w[artist track album].include?(type)
          return render_api_error(
            code: 'validation_failed',
            message: 'type must be one of: artist, track, album',
            status: :bad_request
          )
        end

        # 1. Search local DB
        local_results = MusicSearchService.search(
          query: q, type: type, track: track, artist: artist, album: album, limit: limit
        )

        local_count = count_results(local_results)
        source = 'local'

        # 2. Fallback to MusicBrainz if fewer than LOCAL_THRESHOLD local results
        if local_count < LOCAL_THRESHOLD
          begin
            external_results = fetch_external_results(q: q, track: track, artist: artist, type: type, limit: limit)
            if external_results.any?
              persisted = persist_external_results(external_results)
              local_results = merge_results(local_results, persisted, limit: limit)
              source = 'mixed' if persisted.any?
            end
          rescue StandardError => e
            Rails.logger.warn("SearchController external fallback failed: #{e.message}")
            # Continue with local results only
          end
        end

        render json: {
          data: {
            results: flatten_results(local_results).first(limit),
            query: { q: q, track: track, artist: artist, album: album, type: type },
            source: source
          }
        }
      end

      private

      def count_results(results)
        results.values.flatten.size
      end

      def flatten_results(results)
        results.values.flatten.sort_by { |r| -(r[:similarity] || 0) }
      end

      def fetch_external_results(q:, track:, artist:, type:, limit:)
        results = []

        if type.nil? || type == 'artist'
          query = q || artist
          if query.present?
            artists = MusicbrainzService.search_artist(query, limit: limit)
            results.concat(artists.map { |a| a.merge(_type: 'artist') })
          end
        end

        if type.nil? || type == 'track'
          track_query = track || q
          if track_query.present?
            recordings = MusicbrainzService.search_recording(track_query, artist, limit: limit)
            results.concat(recordings.map { |r| r.merge(_type: 'recording') })
          end
        end

        results
      end

      def persist_external_results(external_results)
        persisted = []

        external_results.each do |result|
          case result[:_type]
          when 'artist'
            band = find_or_create_band_from_mb(result)
            persisted << format_persisted_artist(band) if band
          when 'recording'
            track = find_or_create_track_from_mb(result)
            persisted << format_persisted_track(track) if track
          end
        rescue StandardError => e
          Rails.logger.warn("SearchController persist failed for #{result[:_type]}: #{e.message}")
          next
        end

        persisted
      end

      def find_or_create_band_from_mb(data)
        mbid = data[:mbid]
        name = data[:name]

        return nil if name.blank?

        if mbid.present?
          band = Band.find_by(musicbrainz_id: mbid)
          return band if band
        end

        band = Band.where("LOWER(name) = LOWER(?)", name).first
        if band
          band.update!(musicbrainz_id: mbid) if mbid.present? && band.musicbrainz_id.blank?
          return band
        end

        Band.create!(
          name: name,
          musicbrainz_id: mbid,
          source: :musicbrainz,
          country: data[:country],
          artist_type: data[:type],
          sort_name: data[:sort_name]
        )
      end

      def find_or_create_track_from_mb(data)
        mbid = data[:mbid]
        return nil if mbid.blank?

        track = Track.find_by(musicbrainz_recording_id: mbid)
        return track if track

        artist_data = data[:artists]&.first
        band = artist_data ? find_or_create_band_from_mb(artist_data) : nil

        release = data[:releases]&.first
        album = release ? find_or_create_album_from_mb(release, band) : nil

        Track.create!(
          name: data[:title],
          band: band,
          album: album,
          musicbrainz_recording_id: mbid,
          duration_ms: data[:length],
          source: :musicbrainz
        )
      end

      def find_or_create_album_from_mb(release, band)
        return nil if release[:mbid].blank?

        album = Album.find_by(musicbrainz_release_id: release[:mbid])
        return album if album

        cover_art_url = begin
          ScrobbleCacheService.get_cover_art_url(release[:mbid], size: 500)
        rescue StandardError
          nil
        end

        Album.create!(
          name: release[:title],
          band: band,
          musicbrainz_release_id: release[:mbid],
          cover_art_url: cover_art_url,
          release_date: parse_release_date(release[:date]),
          release_type: release[:release_type]&.downcase,
          source: :musicbrainz
        )
      end

      def parse_release_date(date_string)
        return nil if date_string.blank?

        case date_string.length
        when 4 then Date.new(date_string.to_i, 1, 1)
        when 7 then Date.strptime(date_string, '%Y-%m')
        when 10 then Date.strptime(date_string, '%Y-%m-%d')
        end
      rescue ArgumentError
        nil
      end

      def format_persisted_artist(band)
        {
          type: 'artist',
          id: band.id,
          name: band.name,
          similarity: 1.0,
          image_url: band.artist_image_url,
          musicbrainz_id: band.musicbrainz_id,
          source: 'external'
        }
      end

      def format_persisted_track(track)
        {
          type: 'track',
          id: track.id,
          name: track.name,
          similarity: 1.0,
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
          source: 'external'
        }
      end

      def merge_results(local_results, persisted, limit:)
        # Collect existing IDs from local results to dedup
        existing_ids = Set.new
        local_results.each_value do |items|
          items.each { |item| existing_ids.add("#{item[:type]}:#{item[:id]}") }
        end

        persisted.each do |item|
          key = "#{item[:type]}:#{item[:id]}"
          next if existing_ids.include?(key)

          bucket = case item[:type]
                   when 'artist' then :artists
                   when 'track' then :tracks
                   when 'album' then :albums
                   end
          next unless bucket

          local_results[bucket] ||= []
          local_results[bucket] << item
          existing_ids.add(key)
        end

        local_results
      end

      def check_rate_limit
        cache_key = "search_rate_limit:#{current_user.id}:#{Time.current.beginning_of_minute.to_i}"
        current_count = Rails.cache.read(cache_key) || 0

        if current_count >= RATE_LIMIT_PER_MINUTE
          raise ApiErrorHandler::RateLimitedError.new(
            'Too many search requests. Maximum 30 per minute.',
            retry_after: Time.current.end_of_minute.to_i
          )
        end

        Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
      end
    end
  end
end
