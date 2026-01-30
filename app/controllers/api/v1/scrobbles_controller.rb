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
          scrobble = build_scrobble(scrobble_data)

          if duplicate_scrobble?(scrobble_data)
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

      private

      def build_scrobble(data)
        current_user.scrobbles.build(
          track_name: data[:track_name],
          artist_name: data[:artist_name],
          album_name: data[:album_name],
          duration_ms: data[:duration_ms],
          played_at: parse_played_at(data[:played_at]),
          source_app: data[:source_app],
          source_device: data[:source_device],
          metadata_status: :pending
        )
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
          metadata_status: scrobble.metadata_status
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
          image_url: band.artist_image_url
        }
      end

      def serialize_album(album)
        {
          id: album.id,
          name: album.name,
          cover_art_url: album.cover_art_url
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
    end
  end
end
