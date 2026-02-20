# frozen_string_literal: true

module Api
  module V1
    class ScrobblesController < BaseController
      MAX_BATCH_SIZE = 50
      MAX_PER_PAGE = 100
      DEFAULT_PER_PAGE = 20
      MAX_RECENT = 50
      DEFAULT_RECENT = 20
      RATE_LIMIT_PER_HOUR = 100

      before_action :check_rate_limit, only: [:create]

      # POST /api/v1/scrobbles
      def create
        scrobbles_params = params.require(:scrobbles)

        if scrobbles_params.length > MAX_BATCH_SIZE
          return render json: error_response(
            'validation_failed',
            "Maximum #{MAX_BATCH_SIZE} scrobbles per request"
          ), status: :unprocessable_entity
        end

        accepted = []
        rejected = []

        scrobbles_params.each_with_index do |scrobble_data, index|
          data = permit_scrobble_params(scrobble_data)

          # DEBUG: Log album_art submission status
          if data[:album_art].present?
            Rails.logger.info("[ScrobbleDebug] album_art RECEIVED for '#{data[:track_name]}' - length: #{data[:album_art].to_s.length} chars, starts_with: #{data[:album_art].to_s[0..30]}...")
          else
            Rails.logger.info("[ScrobbleDebug] album_art NOT SENT for '#{data[:track_name]}' - artwork_uri: #{data[:artwork_uri].present? ? 'present' : 'nil'}")
          end

          scrobble = build_scrobble(data)
          attach_album_art(scrobble, data[:album_art])

          if duplicate_scrobble?(data)
            # Silently skip duplicates per PRD
            next
          end

          if scrobble.valid?
            scrobble.save!
            accepted << serialize_scrobble_summary(scrobble)
            log_scrobble_submission(scrobble)
          else
            rejected << {
              index: index,
              errors: scrobble.errors.map { |e| { field: e.attribute, message: e.message } }
            }
          end
        end

        # Invalidate cache after successful submissions
        ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id) if accepted.any?

        if rejected.any?
          render json: error_response(
            'validation_failed',
            'One or more scrobbles failed validation',
            rejected
          ), status: :unprocessable_entity
        else
          render json: {
            data: {
              accepted: accepted.length,
              rejected: 0,
              scrobbles: accepted
            }
          }, status: :created
        end
      end

      # GET /api/v1/scrobbles
      def index
        scrobbles = current_user.scrobbles.recent
        scrobbles = apply_filters(scrobbles)
        scrobbles = apply_cursor_pagination(scrobbles)

        render json: {
          data: {
            scrobbles: scrobbles.map { |s| serialize_scrobble(s) },
            pagination: pagination_metadata(scrobbles)
          }
        }
      end

      # GET /api/v1/scrobbles/recent
      # Cached for 60 seconds per user
      def recent
        limit = [params[:limit]&.to_i || DEFAULT_RECENT, MAX_RECENT].min
        scrobbles = ScrobbleCacheService.get_recent_scrobbles(current_user, limit: limit)

        render json: {
          data: {
            scrobbles: scrobbles.map { |s| serialize_scrobble(s) }
          }
        }
      end

      # GET /api/v1/users/:user_id/scrobbles
      def user_scrobbles
        user = User.find(params[:user_id])

        # TODO: Check privacy settings when implemented
        scrobbles = user.scrobbles.recent
        scrobbles = apply_filters(scrobbles)
        scrobbles = apply_cursor_pagination(scrobbles)

        render json: {
          data: {
            scrobbles: scrobbles.map { |s| serialize_scrobble(s) },
            pagination: pagination_metadata(scrobbles)
          }
        }
      end

      # DELETE /api/v1/scrobbles/:id
      def destroy
        scrobble = current_user.scrobbles.find(params[:id])
        scrobble.destroy!
        head :no_content
      end

      # PATCH /api/v1/scrobbles/:id/artwork
      # Set preferred artwork for a scrobble (overrides album artwork)
      def update_artwork
        scrobble = current_user.scrobbles.find(params[:id])
        artwork_url = params[:artwork_url]

        if artwork_url.blank?
          return render json: error_response(
            'validation_failed',
            'artwork_url is required'
          ), status: :unprocessable_entity
        end

        if scrobble.update(preferred_artwork_url: artwork_url)
          # Invalidate cache so the new artwork shows up
          ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id)

          render json: {
            data: {
              message: 'Preferred artwork set successfully',
              scrobble: serialize_scrobble_with_artwork(scrobble)
            }
          }
        else
          render json: error_response(
            'validation_failed',
            'Could not update artwork',
            scrobble.errors.full_messages
          ), status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/scrobbles/:id/artwork
      # Clear preferred artwork (revert to album artwork)
      def clear_artwork
        scrobble = current_user.scrobbles.find(params[:id])

        scrobble.update!(preferred_artwork_url: nil)

        # Invalidate cache
        ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id)

        render json: {
          data: {
            message: 'Preferred artwork cleared',
            scrobble: serialize_scrobble_with_artwork(scrobble)
          }
        }
      end

      # POST /api/v1/scrobbles/from_lastfm
      # Convert a Last.fm track to a scrobble with preferred artwork
      def from_lastfm
        data = params.require(:scrobble).permit(
          :track_name, :artist_name, :album_name, :played_at,
          :preferred_artwork_url, :lastfm_url, :lastfm_loved,
          :musicbrainz_recording_id, :artist_mbid, :album_mbid,
          :artwork_uri
        )

        # Validate required fields
        if data[:track_name].blank? || data[:artist_name].blank?
          return render json: error_response(
            'validation_failed',
            'track_name and artist_name are required'
          ), status: :unprocessable_entity
        end

        played_at = parse_played_at(data[:played_at])
        if played_at.blank?
          return render json: error_response(
            'validation_failed',
            'played_at is required'
          ), status: :unprocessable_entity
        end

        # Check for duplicate (existing scrobble with same track at same time)
        if Scrobble.duplicate?(
          user_id: current_user.id,
          track_name: data[:track_name],
          artist_name: data[:artist_name],
          played_at: played_at
        )
          # Find and return the existing scrobble
          existing = current_user.scrobbles
            .where(track_name: data[:track_name], artist_name: data[:artist_name])
            .where('played_at BETWEEN ? AND ?', played_at - 30.seconds, played_at + 30.seconds)
            .first

          if existing
            # Update preferred artwork if provided
            if data[:preferred_artwork_url].present?
              existing.update!(preferred_artwork_url: data[:preferred_artwork_url])
              ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id)
            end

            return render json: {
              data: {
                message: 'Scrobble already exists, updated artwork',
                scrobble: serialize_scrobble_with_artwork(existing)
              }
            }
          end
        end

        # Create the scrobble from Last.fm data
        scrobble = current_user.scrobbles.build(
          track_name: data[:track_name],
          artist_name: data[:artist_name],
          album_name: data[:album_name],
          played_at: played_at,
          source_app: 'lastfm',
          duration_ms: nil, # Last.fm doesn't provide duration
          metadata_status: :pending,
          # Preferred artwork from user selection
          preferred_artwork_url: data[:preferred_artwork_url],
          # Last.fm original artwork as fallback
          artwork_uri: data[:artwork_uri],
          # Last.fm specific metadata
          lastfm_url: data[:lastfm_url],
          lastfm_loved: data[:lastfm_loved] || false,
          # MusicBrainz IDs from Last.fm
          musicbrainz_recording_id: data[:musicbrainz_recording_id],
          artist_mbid: data[:artist_mbid],
          album_mbid: data[:album_mbid]
        )

        if scrobble.save
          # Invalidate cache
          ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id)

          render json: {
            data: {
              message: 'Last.fm track converted to scrobble',
              scrobble: serialize_scrobble_with_artwork(scrobble)
            }
          }, status: :created
        else
          render json: error_response(
            'validation_failed',
            'Could not create scrobble',
            scrobble.errors.full_messages
          ), status: :unprocessable_entity
        end
      end

      # POST /api/v1/scrobbles/:id/refresh_artwork
      # Manually refresh artwork for a scrobble's track
      def refresh_artwork
        scrobble = current_user.scrobbles.find(params[:id])

        result = ArtworkRefreshService.refresh_for_scrobble(scrobble)

        case result[:status]
        when 'success'
          # Invalidate cache so the new artwork shows up
          ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id)

          render json: {
            data: {
              status: 'success',
              message: 'Artwork refreshed successfully',
              artwork_url: result[:artwork_url],
              scrobble: serialize_scrobble(scrobble.reload)
            }
          }
        when 'already_has_artwork'
          render json: {
            data: {
              status: 'already_has_artwork',
              message: 'This track already has artwork',
              artwork_url: result[:artwork_url]
            }
          }
        when 'no_track'
          render json: error_response(
            'no_track',
            'This scrobble has no associated track metadata'
          ), status: :unprocessable_entity
        else
          render json: {
            data: {
              status: 'not_found',
              message: 'Could not find artwork from any source'
            }
          }
        end
      end

      private

      def permit_scrobble_params(scrobble_data)
        scrobble_data.permit(
          :track_name, :artist_name, :album_name, :duration_ms,
          :played_at, :source_app, :source_device,
          :album_artist, :genre, :year, :release_date,
          :artwork_uri, :album_art
        ).to_h.with_indifferent_access
      end

      def build_scrobble(data)
        current_user.scrobbles.build(
          track_name: data[:track_name],
          artist_name: data[:artist_name],
          album_name: data[:album_name],
          duration_ms: data[:duration_ms],
          played_at: parse_played_at(data[:played_at]),
          source_app: data[:source_app],
          source_device: data[:source_device],
          metadata_status: :pending,
          # Android metadata fields
          album_artist: data[:album_artist],
          genre: data[:genre],
          year: data[:year],
          release_date: parse_release_date(data[:release_date]),
          artwork_uri: data[:artwork_uri]
        )
      end

      def parse_release_date(value)
        return nil unless value.present?

        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def attach_album_art(scrobble, album_art_data)
        return unless album_art_data.present?

        begin
          # Support both raw base64 and data URI format
          if album_art_data.start_with?('data:')
            # Parse data URI: data:image/jpeg;base64,/9j/4AAQ...
            match = album_art_data.match(/\Adata:([^;]+);base64,(.+)\z/)
            return unless match

            content_type = match[1]
            base64_data = match[2]
          else
            # Raw base64, assume JPEG
            content_type = 'image/jpeg'
            base64_data = album_art_data
          end

          decoded_data = Base64.strict_decode64(base64_data)

          # Determine file extension from content type
          extension = case content_type
                      when 'image/jpeg' then 'jpg'
                      when 'image/png' then 'png'
                      when 'image/webp' then 'webp'
                      else 'jpg'
                      end

          filename = "album_art_#{SecureRandom.hex(8)}.#{extension}"

          scrobble.album_art.attach(
            io: StringIO.new(decoded_data),
            filename: filename,
            content_type: content_type
          )
        rescue ArgumentError
          # Invalid base64 data - silently ignore, validation will catch invalid attachments
        end
      end

      def parse_played_at(value)
        return nil unless value.present?

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def duplicate_scrobble?(data)
        played_at = parse_played_at(data[:played_at])
        return false unless played_at

        Scrobble.duplicate?(
          user_id: current_user.id,
          track_name: data[:track_name],
          artist_name: data[:artist_name],
          played_at: played_at
        )
      end

      def apply_filters(scrobbles)
        scrobbles = scrobbles.since(Time.zone.parse(params[:since])) if params[:since].present?
        scrobbles = scrobbles.until_time(Time.zone.parse(params[:until])) if params[:until].present?
        scrobbles
      end

      def apply_cursor_pagination(scrobbles)
        limit = [params[:limit]&.to_i || DEFAULT_PER_PAGE, MAX_PER_PAGE].min

        if params[:cursor].present?
          cursor_time = Time.zone.parse(params[:cursor])
          scrobbles = scrobbles.where('played_at < ?', cursor_time)
        end

        scrobbles.limit(limit + 1).includes(track: [:band, :album])
      end

      def pagination_metadata(scrobbles)
        has_more = scrobbles.length > page_limit
        last_scrobble = scrobbles.take(page_limit).last

        {
          next_cursor: last_scrobble&.played_at&.iso8601,
          has_more: has_more
        }
      end

      def page_limit
        [params[:limit]&.to_i || DEFAULT_PER_PAGE, MAX_PER_PAGE].min
      end

      def serialize_scrobble_summary(scrobble)
        {
          id: scrobble.id,
          track_name: scrobble.track_name,
          artist_name: scrobble.artist_name,
          album_name: scrobble.album_name,
          played_at: scrobble.played_at.iso8601,
          metadata_status: scrobble.metadata_status,
          artwork_url: scrobble.effective_artwork_url,
          genre: scrobble.genre,
          year: scrobble.year,
          album_artist: scrobble.album_artist
        }
      end

      def serialize_scrobble(scrobble)
        result = {
          id: scrobble.id,
          track_name: scrobble.track_name,
          artist_name: scrobble.artist_name,
          album_name: scrobble.album_name,
          played_at: scrobble.played_at.iso8601,
          source_app: scrobble.source_app,
          artwork_url: scrobble.effective_artwork_url,
          genre: scrobble.genre,
          year: scrobble.year,
          album_artist: scrobble.album_artist,
          track: nil
        }

        if scrobble.track.present?
          result[:track] = serialize_track(scrobble.track)
        end

        result
      end

      def serialize_track(track)
        {
          id: track.id,
          name: track.name,
          duration_ms: track.duration_ms,
          artist: track.band ? serialize_artist(track.band) : nil,
          album: track.album ? serialize_album(track.album) : nil
        }
      end

      def serialize_artist(band)
        {
          id: band.id,
          name: band.name,
          image_url: band.resolved_artist_image_url
        }
      end

      def serialize_album(album)
        {
          id: album.id,
          name: album.name,
          cover_art_url: album.resolved_cover_art_url
        }
      end

      def error_response(code, message, details = nil)
        response = {
          error: {
            code: code,
            message: message
          }
        }
        response[:error][:details] = details if details
        response
      end

      # Rate limiting: max 100 scrobbles per hour per user
      def check_rate_limit
        cache_key = "scrobble_rate_limit:#{current_user.id}:#{Time.current.beginning_of_hour.to_i}"
        current_count = Rails.cache.read(cache_key) || 0

        if current_count >= RATE_LIMIT_PER_HOUR
          render json: error_response(
            'rate_limited',
            'Too many scrobble submissions. Maximum 100 per hour.',
            { retry_after: Time.current.end_of_hour.to_i }
          ), status: :too_many_requests
          return
        end

        # Increment the counter
        Rails.cache.write(cache_key, current_count + 1, expires_in: 1.hour)
      end

      # Log scrobble submissions for abuse detection
      def log_scrobble_submission(scrobble)
        Rails.logger.info(
          "[ScrobbleSubmission] user_id=#{current_user.id} " \
          "scrobble_id=#{scrobble.id} " \
          "track=\"#{scrobble.track_name}\" " \
          "artist=\"#{scrobble.artist_name}\" " \
          "source_app=#{scrobble.source_app} " \
          "ip=#{request.remote_ip}"
        )
      end

      # Serialize scrobble with artwork details for artwork update responses
      def serialize_scrobble_with_artwork(scrobble)
        {
          id: scrobble.id,
          track_name: scrobble.track_name,
          artist_name: scrobble.artist_name,
          album_name: scrobble.album_name,
          played_at: scrobble.played_at.iso8601,
          artwork_url: scrobble.effective_artwork_url,
          preferred_artwork_url: scrobble.preferred_artwork_url,
          has_preferred_artwork: scrobble.has_preferred_artwork?,
          metadata_status: scrobble.metadata_status
        }
      end
    end
  end
end
