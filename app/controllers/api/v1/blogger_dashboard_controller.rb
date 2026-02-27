# frozen_string_literal: true

module Api
  module V1
    class BloggerDashboardController < BaseController
      # GET /api/v1/blogger_dashboard
      # Returns all dashboard data for bloggers in a single optimized request
      def show
        json_response({
          profile: profile_data,
          unread_notifications_count: unread_notifications_count,
          recent_reviews: recent_reviews,
          recently_played: [],
          following_feed_preview: following_feed_preview,
          recent_posts: recent_posts,
          posts_stats: posts_stats
        })
      end

      private

      def profile_data
        {
          id: current_user.id,
          username: current_user.username,
          email: current_user.email,
          about_me: current_user.about_me,
          profile_image_url: profile_image_url(current_user),
          role: current_user.role,
          plan: current_user.plan ? { key: current_user.plan.key, name: current_user.plan.name } : nil,
          abilities: current_user.abilities,
          display_name: current_user.display_name,
          location: current_user.location,
          followers_count: current_user.followers_count,
          following_count: current_user.following_count,
          reviews_count: current_user.reviews_count,
          posts_count: current_user.posts.count,
          lastfm_connected: current_user.lastfm_connected?,
          lastfm_username: current_user.lastfm_username,
          email_confirmed: current_user.email_confirmed?,
          admin: current_user.admin?,
          preferred_streaming_platform: current_user.preferred_streaming_platform
        }
      end

      def unread_notifications_count
        current_user.notifications.where(read: false).count
      end

      def recent_reviews
        reviews = current_user.reviews
                              .includes(:band, :track)
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

      def following_feed_preview
        followed_user_ids = current_user.following.where(disabled: false).pluck(:id)

        conditions = ['reviews.user_id = ?']
        values = [current_user.id]

        if followed_user_ids.any?
          conditions << 'reviews.user_id IN (?)'
          values << followed_user_ids
        end

        reviews = Review.from_active_users
                        .includes(:user, :band)
                        .where(conditions.join(' OR '), *values)
                        .order(created_at: :desc)
                        .limit(5)

        review_ids = reviews.map(&:id)
        liked_review_ids = current_user.review_likes
                                       .where(review_id: review_ids)
                                       .pluck(:review_id)
                                       .to_set

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
            likes_count: review.likes_count,
            comments_count: review.comments_count,
            liked_by_current_user: liked_review_ids.include?(review.id)
          }
        end
      end

      def recent_posts
        posts = current_user.posts
                            .order(created_at: :desc)
                            .limit(5)

        posts.map do |post|
          {
            id: post.id,
            title: post.title,
            slug: post.slug,
            excerpt: post.excerpt,
            status: post.status,
            featured: post.featured,
            publish_date: post.publish_date&.iso8601,
            created_at: post.created_at.iso8601,
            updated_at: post.updated_at.iso8601
          }
        end
      end

      def posts_stats
        {
          total_posts: current_user.posts.count,
          published_posts: current_user.posts.published.count,
          draft_posts: current_user.posts.draft.count,
          scheduled_posts: current_user.posts.scheduled.count
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
