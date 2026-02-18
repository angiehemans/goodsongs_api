# frozen_string_literal: true

module Api
  module V1
    class FanDashboardController < BaseController
      # GET /api/v1/fan_dashboard
      # Returns all dashboard data in a single optimized request
      # Reduces 17+ API calls to 1 for the fan dashboard
      def show
        json_response({
          profile: profile_data,
          unread_notifications_count: unread_notifications_count,
          recent_reviews: recent_reviews,
          recently_played: recently_played,
          following_feed_preview: following_feed_preview,
          favorite_bands: favorite_bands,
          stats: dashboard_stats
        })
      end

      private

      # User profile data with counter caches (no expensive COUNT queries)
      def profile_data
        {
          id: current_user.id,
          username: current_user.username,
          email: current_user.email,
          about_me: current_user.about_me,
          profile_image_url: profile_image_url(current_user),
          account_type: current_user.account_type,
          display_name: current_user.display_name,
          location: current_user.location,
          followers_count: current_user.followers_count,
          following_count: current_user.following_count,
          reviews_count: current_user.reviews_count,
          lastfm_connected: current_user.lastfm_connected?,
          lastfm_username: current_user.lastfm_username,
          email_confirmed: current_user.email_confirmed?,
          admin: current_user.admin?
        }
      end

      # Unread notifications count (single query with index)
      def unread_notifications_count
        current_user.notifications.where(read: false).count
      end

      # User's recent reviews with eager loading
      def recent_reviews
        reviews = current_user.reviews
                              .includes(:band)
                              .order(created_at: :desc)
                              .limit(5)

        reviews.map do |review|
          {
            id: review.id,
            song_name: review.song_name,
            band_name: review.band_name,
            artwork_url: review.artwork_url,
            created_at: review.created_at.iso8601,
            likes_count: review.likes_count,
            comments_count: review.comments_count
          }
        end
      end

      # Recently played tracks from all sources
      def recently_played
        result = RecentlyPlayedService.new(current_user).fetch(limit: 10)
        result[:tracks]
      rescue StandardError => e
        Rails.logger.error("FanDashboard recently_played error: #{e.message}")
        []
      end

      # Preview of feed including own reviews and reviews from followed users
      def following_feed_preview
        reviews = combined_feed_query(limit: 5)

        reviews.map do |review|
          {
            id: review.id,
            song_name: review.song_name,
            band_name: review.band_name,
            artwork_url: review.artwork_url,
            review_text: review.review_text.truncate(150),
            author: {
              id: review.user.id,
              username: review.user.username,
              profile_image_url: profile_image_url(review.user)
            },
            created_at: review.created_at.iso8601,
            likes_count: review.likes_count
          }
        end
      end

      # Combined feed: user's own reviews + reviews from followed users + reviews about followed bands
      def combined_feed_query(limit:)
        followed_user_ids = current_user.following.where(disabled: false).pluck(:id)
        followed_band_ids = Band.where(user_id: followed_user_ids).pluck(:id) if followed_user_ids.any?

        # Build conditions: own reviews OR from followed users OR about followed bands
        conditions = ['reviews.user_id = ?']
        values = [current_user.id]

        if followed_user_ids.any?
          conditions << 'reviews.user_id IN (?)'
          values << followed_user_ids
        end

        if followed_band_ids&.any?
          conditions << 'reviews.band_id IN (?)'
          values << followed_band_ids
        end

        Review.from_active_users
              .includes(:user, :band)
              .where(conditions.join(' OR '), *values)
              .order(created_at: :desc)
              .limit(limit)
      end

      # User's favorite bands
      def favorite_bands
        favorites = current_user.favorite_bands
                                .includes(:band)
                                .order(:position)
                                .limit(5)

        favorites.map do |fav|
          next unless fav.band

          {
            id: fav.band.id,
            name: fav.band.name,
            slug: fav.band.slug,
            image_url: fav.band.artist_image_url,
            position: fav.position
          }
        end.compact
      rescue StandardError
        # favorite_bands association might not exist
        []
      end

      # Quick stats for the dashboard
      def dashboard_stats
        {
          total_scrobbles: current_user.scrobbles.count,
          scrobbles_this_week: current_user.scrobbles.where('played_at > ?', 1.week.ago).count
        }
      end

      def profile_image_url(user)
        return nil unless user.profile_image.attached?

        Rails.application.routes.url_helpers.rails_blob_url(
          user.profile_image,
          **active_storage_url_options
        )
      end

      def active_storage_url_options
        if ENV['API_URL'].present?
          uri = URI.parse(ENV['API_URL'])
          port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
          { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
        else
          Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
        end
      end
    end
  end
end
