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
            artwork_url: ReviewSerializer.resolved_artwork_url(review),
            created_at: review.created_at.iso8601,
            likes_count: review.likes_count,
            comments_count: review.comments_count
          }
        end
      end

      def following_feed_preview
        items = QueryService.unified_following_feed_preview(current_user, limit: 20)

        # Batch-load liked review and post IDs
        review_ids = items.select { |i| i[:type] == 'review' }.map { |i| i[:record].id }
        post_ids = items.select { |i| i[:type] == 'post' }.map { |i| i[:record].id }
        event_ids = items.select { |i| i[:type] == 'event' }.map { |i| i[:record].id }
        liked_review_ids = review_ids.any? ? current_user.review_likes.where(review_id: review_ids).pluck(:review_id).to_set : Set.new
        liked_post_ids = post_ids.any? ? current_user.post_likes.where(post_id: post_ids).pluck(:post_id).to_set : Set.new
        liked_event_ids = event_ids.any? ? current_user.event_likes.where(event_id: event_ids).pluck(:event_id).to_set : Set.new

        items.map do |item|
          case item[:type]
          when 'review'
            review = item[:record]
            {
              type: 'review',
              data: {
                id: review.id,
                song_name: review.song_name,
                band_name: review.band_name,
                artwork_url: ReviewSerializer.resolved_artwork_url(review),
                review_text: review.review_text.truncate(150),
                author: feed_author_data(review.user),
                created_at: review.created_at.iso8601,
                likes_count: review.likes_count,
                comments_count: review.comments_count,
                liked_by_current_user: liked_review_ids.include?(review.id)
              }
            }
          when 'post'
            post = item[:record]
            {
              type: 'post',
              data: {
                id: post.id,
                title: post.title,
                slug: post.slug,
                excerpt: post.excerpt,
                featured_image_url: post.featured_image_url,
                author: feed_author_data(post.user),
                created_at: post.created_at.iso8601,
                likes_count: post.likes_count,
                comments_count: post.comments_count,
                liked_by_current_user: liked_post_ids.include?(post.id)
              }
            }
          when 'event'
            event = item[:record]
            {
              type: 'event',
              data: {
                id: event.id,
                name: event.name,
                event_date: event.event_date,
                author: feed_author_data(event.user),
                created_at: event.created_at.iso8601,
                likes_count: event.likes_count,
                comments_count: event.comments_count,
                liked_by_current_user: liked_event_ids.include?(event.id),
                venue: event.venue ? { id: event.venue.id, name: event.venue.name } : nil,
                band: event.band ? { id: event.band.id, name: event.band.name } : nil
              }
            }
          end
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
          **ImageUrlHelper.active_storage_url_options
        )
      end

      def feed_author_data(user)
        data = {
          id: user.id,
          username: user.username,
          display_name: user.display_name,
          role: user.role,
          plan: user.plan ? { key: user.plan.key, name: user.plan.name } : nil,
          profile_image_url: author_avatar_url(user)
        }
        data[:band_slug] = user.primary_band.slug if user.band? && user.primary_band
        data
      end

      def author_avatar_url(user)
        if user.band? && user.primary_band
          band_picture_url(user.primary_band) || user.primary_band.resolved_artist_image_url
        else
          profile_image_url(user)
        end
      end

      def band_picture_url(band)
        return nil unless band.profile_picture.attached?

        Rails.application.routes.url_helpers.rails_blob_url(
          band.profile_picture,
          **ImageUrlHelper.active_storage_url_options
        )
      end
    end
  end
end
