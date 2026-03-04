# frozen_string_literal: true

module Api
  module V1
    class BlogDashboardController < BaseController
      # GET /api/v1/blog_dashboard
      # Returns comprehensive blog dashboard data including analytics, content stats, and notifications
      def show
        json_response({
          totals: totals_data,
          page_views_over_time: page_views_last_60_days,
          traffic_sources: traffic_sources_data,
          recent_posts: recent_posts_data,
          recent_notifications: recent_notifications_data,
          follower_growth: follower_growth_data,
          top_performing_posts: top_performing_posts_data
        })
      end

      private

      # Total counts for key metrics
      def totals_data
        {
          page_views: total_page_views,
          posts: current_user.posts.count,
          recommendations: current_user.reviews.count,
          followers: current_user.followers_count,
          comments: total_comments
        }
      end

      def total_page_views
        PageView.for_owner(current_user).count
      end

      # Total comments on user's posts + reviews (recommendations)
      def total_comments
        post_comments = PostComment.joins(:post).where(posts: { user_id: current_user.id }).count
        review_comments = ReviewComment.joins(:review).where(reviews: { user_id: current_user.id }).count
        post_comments + review_comments
      end

      # Page views grouped by day for the last 60 days
      def page_views_last_60_days
        views = PageView.for_owner(current_user)
                        .in_period(60.days.ago.beginning_of_day, Time.current.end_of_day)
                        .group_by_day(:created_at, time_zone: Time.zone.name)
                        .count

        views.map { |date, count| { date: date.to_date.iso8601, views: count } }
      end

      # Traffic sources breakdown with percentages
      def traffic_sources_data
        views = PageView.for_owner(current_user)
                        .in_period(60.days.ago.beginning_of_day, Time.current.end_of_day)
        total = views.count

        sources = views.group(:referrer_source).count.sort_by { |_, count| -count }

        sources.map do |(source, count)|
          {
            source: source,
            views: count,
            percentage: total > 0 ? (count.to_f / total * 100).round(1) : 0
          }
        end
      end

      # 5 most recent posts
      def recent_posts_data
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
            likes_count: post.post_likes.count,
            comments_count: post.post_comments.count
          }
        end
      end

      # 5 most recent notifications
      def recent_notifications_data
        notifications = current_user.notifications
                                    .includes(:actor)
                                    .order(created_at: :desc)
                                    .limit(5)

        notifications.map do |notification|
          {
            id: notification.id,
            type: notification.notification_type,
            read: notification.read,
            actor: notification.actor ? {
              id: notification.actor.id,
              username: notification.actor.username,
              display_name: notification.actor.display_name,
              profile_image_url: profile_image_url(notification.actor)
            } : nil,
            created_at: notification.created_at.iso8601
          }
        end
      end

      # Follower growth over the last 3 months, grouped by week
      def follower_growth_data
        follows = Follow.where(followed_id: current_user.id)
                        .where(created_at: 3.months.ago.beginning_of_day..Time.current.end_of_day)
                        .group_by_week(:created_at, time_zone: Time.zone.name)
                        .count

        follows.map { |date, count| { week: date.to_date.iso8601, new_followers: count } }
      end

      # 5 top performing posts based on views + interactions (likes + comments)
      def top_performing_posts_data
        posts = current_user.posts.published

        # Get page view counts for posts
        post_view_counts = PageView.for_owner(current_user)
                                   .where(viewable_type: 'Post')
                                   .group(:viewable_id)
                                   .count

        # Calculate scores for each post
        scored_posts = posts.map do |post|
          views = post_view_counts[post.id] || 0
          likes = post.post_likes.count
          comments = post.post_comments.count
          # Score: views + (2 * likes) + (3 * comments) - weighting interactions higher
          score = views + (likes * 2) + (comments * 3)

          {
            post: post,
            views: views,
            likes: likes,
            comments: comments,
            score: score
          }
        end

        # Sort by score and take top 5
        top_posts = scored_posts.sort_by { |p| -p[:score] }.first(5)

        top_posts.map do |data|
          post = data[:post]
          {
            id: post.id,
            title: post.title,
            slug: post.slug,
            excerpt: post.excerpt,
            publish_date: post.publish_date&.iso8601,
            views: data[:views],
            likes: data[:likes],
            comments: data[:comments],
            engagement_score: data[:score]
          }
        end
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
