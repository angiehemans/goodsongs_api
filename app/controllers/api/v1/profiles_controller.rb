# frozen_string_literal: true

module Api
  module V1
    class ProfilesController < BaseController
      skip_before_action :authenticate_request

      # GET /api/v1/profiles/bands/:slug
      def band
        band = Band.find_by("lower(slug) = ?", params[:slug].to_s.downcase)
        return render json: { error: "not_found", message: "Band not found" }, status: :not_found unless band

        user = band.user
        render_custom_profile(user)
      end

      # GET /api/v1/profiles/users/:username
      def user
        user = User.find_by("lower(username) = ?", params[:username].to_s.downcase)
        return render json: { error: "not_found", message: "User not found" }, status: :not_found unless user

        # Fans don't have customizable profiles
        if user.fan?
          return render json: { data: UserSerializer.public_profile(user) }
        end

        render_custom_profile(user)
      end

      # GET /api/v1/profiles/bands/:slug/posts/:post_slug
      def band_post
        band = Band.find_by("lower(slug) = ?", params[:slug].to_s.downcase)
        return render json: { error: "not_found", message: "Band not found" }, status: :not_found unless band

        render_themed_post(band.user, params[:post_slug])
      end

      # GET /api/v1/profiles/users/:username/posts/:post_slug
      def user_post
        user = User.find_by("lower(username) = ?", params[:username].to_s.downcase)
        return render json: { error: "not_found", message: "User not found" }, status: :not_found unless user

        render_themed_post(user, params[:post_slug])
      end

      private

      def render_custom_profile(user)
        theme = user.profile_theme
        unless theme
          return render json: {
            data: build_default_profile_response(user)
          }
        end

        render json: {
          data: build_profile_response(user, theme)
        }
      end

      def build_default_profile_response(user)
        resolver = ProfileSectionResolver.new(user)
        default_sections = ProfileTheme.default_sections_for_role(user.role).select { |s| s[:visible] }

        {
          user: UserSerializer.public_profile(user),
          theme: nil,
          sections: default_sections.map { |s| resolver.resolve_section(s) }
        }
      end

      def build_profile_response(user, theme)
        resolver = ProfileSectionResolver.new(user)

        # Filter sections by visibility and plan eligibility
        visible_sections = filter_eligible_sections(theme.sections, user)
        resolved_sections = visible_sections.map { |s| resolver.resolve_section(s) }

        {
          user: UserSerializer.public_profile(user),
          theme: ProfileThemeSerializer.public(theme),
          sections: resolved_sections
        }
      end

      def filter_eligible_sections(sections, user)
        sections.select do |section|
          next false unless section['visible'] || section[:visible]

          type = section['type'] || section[:type]

          # Check plan eligibility for gated sections
          case type
          when 'mailing_list'
            user.can?(:profile_mailing_list_section)
          when 'merch'
            user.can?(:profile_merch_section)
          else
            true
          end
        end.sort_by { |s| s['order'] || s[:order] || 0 }
      end

      def render_themed_post(user, post_slug)
        post = user.posts.published.find_by(slug: post_slug)
        return render json: { error: "not_found", message: "Post not found" }, status: :not_found unless post

        theme = user.profile_theme
        layout = theme ? theme.resolved_single_post_layout : ProfileTheme::DEFAULT_SINGLE_POST_LAYOUT

        data = {
          post: PostSerializer.full(post),
          user: UserSerializer.public_profile(user),
          theme: theme ? ProfileThemeSerializer.public(theme) : nil
        }

        # Conditionally include comments
        if layout['show_comments']
          total = post.post_comments.count
          comments = post.post_comments
                        .includes(:user, :mentions)
                        .order(created_at: :desc)
                        .limit(20)

          data[:comments] = {
            data: comments.map { |c| serialize_public_comment(c) },
            pagination: {
              current_page: 1,
              total_count: total,
              total_pages: (total / 20.0).ceil,
              per_page: 20
            }
          }
        end

        # Conditionally include related posts
        if layout['show_related_posts']
          related = user.posts.published.where.not(id: post.id).order(publish_date: :desc).limit(3)
          data[:related_posts] = related.map { |p| PostSerializer.summary(p) }
        end

        # Conditionally include navigation
        if layout['show_navigation']
          data[:navigation] = build_post_navigation(user, post)
        end

        render json: { data: data }
      end

      def serialize_public_comment(comment)
        result = {
          id: comment.id,
          body: comment.body,
          anonymous: comment.anonymous?,
          likes_count: comment.likes_count,
          created_at: comment.created_at,
          updated_at: comment.updated_at
        }

        if comment.anonymous?
          result[:guest_name] = comment.guest_name
        elsif comment.user
          mentions = comment.mentions
          result[:formatted_body] = MentionService.format_content(comment.body, mentions)
          result[:mentions] = mentions.map do |mention|
            {
              id: mention.id,
              username: mention.user&.username,
              display_name: mention.user&.display_name,
              offset: mention.offset,
              length: mention.length
            }
          end
          result[:author] = {
            id: comment.user.id,
            username: comment.user.username,
            display_name: comment.user.display_name,
            profile_image_url: UserSerializer.profile_image_url(comment.user)
          }
        end

        result
      end

      def build_post_navigation(user, post)
        posts = user.posts.published.order(publish_date: :desc)

        next_post = posts.where("publish_date > ?", post.publish_date).order(publish_date: :asc).first
        previous_post = posts.where("publish_date < ?", post.publish_date).first

        {
          next_post: next_post ? { title: next_post.title, slug: next_post.slug } : nil,
          previous_post: previous_post ? { title: previous_post.title, slug: previous_post.slug } : nil
        }
      end
    end
  end
end
