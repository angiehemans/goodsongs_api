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
          role: current_user.role,
          plan: current_user.plan ? { key: current_user.plan.key, name: current_user.plan.name } : nil,
          abilities: current_user.abilities,
          display_name: current_user.display_name,
          location: current_user.location,
          followers_count: current_user.followers_count,
          following_count: current_user.following_count,
          reviews_count: current_user.reviews_count,
          lastfm_connected: current_user.lastfm_connected?,
          lastfm_username: current_user.lastfm_username,
          email_confirmed: current_user.email_confirmed?,
          admin: current_user.admin?,
          preferred_streaming_platform: current_user.preferred_streaming_platform
        }
      end

      # Unread notifications count (single query with index)
      def unread_notifications_count
        current_user.notifications.where(read: false).count
      end

      # User's recent reviews with eager loading
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
            comments_count: review.comments_count,
            track: review.track ? track_with_links(review.track) : nil,
            band: band_with_links(review.band)
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

      # Preview of unified feed: reviews + posts + events from followed users
      def following_feed_preview
        items = QueryService.unified_following_feed_preview(current_user, limit: 20)

        # Batch-load liked review and post IDs for the current user
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
                liked_by_current_user: liked_review_ids.include?(review.id),
                track: review.track ? track_with_links(review.track) : nil,
                band: band_with_links(review.band)
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
                image_url: EventSerializer.event_image_url(event),
                author: feed_author_data(event.user),
                created_at: event.created_at.iso8601,
                likes_count: event.likes_count,
                comments_count: event.comments_count,
                liked_by_current_user: liked_event_ids.include?(event.id),
                venue: event.venue ? { id: event.venue.id, name: event.venue.name } : nil,
                band: event.band ? { id: event.band.id, name: event.band.name, slug: event.band.slug } : nil
              }
            }
          end
        end
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

      def track_with_links(track)
        links = track.streaming_links || {}
        {
          id: track.id,
          name: track.name,
          streaming_links: links,
          preferred_track_link: preferred_track_link(links),
          songlink_url: track.songlink_url,
          songlink_search_url: track.songlink_search_url
        }
      end

      def band_with_links(band)
        return nil unless band

        {
          id: band.id,
          name: band.name,
          slug: band.slug,
          spotify_link: band.spotify_link,
          apple_music_link: band.apple_music_link,
          bandcamp_link: band.bandcamp_link,
          youtube_music_link: band.youtube_music_link,
          soundcloud_link: band.soundcloud_link,
          preferred_band_link: preferred_band_link(band)
        }
      end

      def preferred_track_link(links)
        pref = current_user.preferred_streaming_platform
        return nil unless pref.present?

        links[pref]
      end

      def preferred_band_link(band)
        pref = current_user.preferred_streaming_platform
        return nil unless pref.present?

        case pref
        when 'spotify' then band.spotify_link
        when 'appleMusic' then band.apple_music_link
        when 'bandcamp' then band.bandcamp_link
        when 'youtubeMusic' then band.youtube_music_link
        when 'soundcloud' then band.soundcloud_link
        end
      end
    end
  end
end
