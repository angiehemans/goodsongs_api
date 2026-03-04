# frozen_string_literal: true

module Api
  module V1
    class TrackingController < BaseController
      include ActionController::Cookies

      skip_before_action :authenticate_request
      skip_before_action :require_onboarding_completed
      before_action :check_rate_limit

      RATE_LIMIT_PER_MINUTE = 100
      DEDUP_WINDOW = 1.hour

      VIEWABLE_TYPES = {
        'post' => 'Post',
        'band' => 'Band',
        'event' => 'Event',
        'custom_page' => 'CustomPage'
      }.freeze

      # POST /api/v1/track
      def create
        Rails.logger.info("[Tracking] Received: viewable_type=#{params[:viewable_type]}, viewable_id=#{params[:viewable_id]}, path=#{params[:path]}")

        viewable = find_viewable
        unless viewable
          Rails.logger.warn("[Tracking] 404: Could not find #{params[:viewable_type]} with id #{params[:viewable_id]}")
          return render_not_found
        end

        owner = determine_owner(viewable)
        return render_not_found unless owner

        # Skip self-views (authenticated owner viewing their own content)
        if self_view?(owner)
          return head :no_content
        end

        # Skip duplicate views (same session + page within dedup window)
        if duplicate_view?(viewable)
          return head :no_content
        end

        page_view = build_page_view(viewable, owner)

        if page_view.save
          head :no_content
        else
          Rails.logger.warn("[Tracking] Failed to save page view: #{page_view.errors.full_messages.join(', ')}")
          head :no_content
        end
      end

      private

      def find_viewable
        viewable_type = VIEWABLE_TYPES[params[:viewable_type]&.downcase]
        viewable_id = params[:viewable_id]

        return nil unless viewable_type && viewable_id.present?

        viewable_type.constantize.find_by(id: viewable_id)
      rescue NameError
        nil
      end

      def determine_owner(viewable)
        case viewable
        when Post
          viewable.user
        when Band
          viewable.user
        when Event
          viewable.band&.user
        else
          nil
        end
      end

      def self_view?(owner)
        return false unless authenticated_user
        authenticated_user.id == owner.id
      end

      def duplicate_view?(viewable)
        PageView.where(
          viewable: viewable,
          session_id: session_id,
          created_at: DEDUP_WINDOW.ago..Time.current
        ).exists?
      end

      def build_page_view(viewable, owner)
        PageView.new(
          viewable: viewable,
          owner: owner,
          path: params[:path].presence || request.path,
          session_id: session_id,
          ip_hash: hashed_ip,
          referrer: params[:referrer],
          referrer_source: ReferrerParser.parse(params[:referrer]),
          user_agent: request.user_agent,
          device_type: DeviceTypeParser.parse(request.user_agent),
          country: GeoipLookup.country(request.remote_ip)
        )
      end

      def session_id
        cookies[:gs_session] ||= {
          value: SecureRandom.uuid,
          expires: 24.hours.from_now,
          httponly: true,
          same_site: :lax
        }
        cookies[:gs_session]
      end

      def hashed_ip
        Digest::SHA256.hexdigest("#{request.remote_ip}:#{Rails.application.secret_key_base}")
      end

      def check_rate_limit
        cache_key = "tracking_rate_limit:#{request.remote_ip}:#{Time.current.beginning_of_minute.to_i}"
        current_count = Rails.cache.read(cache_key) || 0

        if current_count >= RATE_LIMIT_PER_MINUTE
          head :too_many_requests
          return
        end

        Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
      end

      def render_not_found
        head :not_found
      end

      def authenticated_user
        @authenticated_user ||= begin
          AuthorizeApiRequest.new(request.headers).call[:user]
        rescue StandardError
          nil
        end
      end
    end
  end
end
