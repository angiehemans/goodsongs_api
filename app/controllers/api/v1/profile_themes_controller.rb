# frozen_string_literal: true

module Api
  module V1
    class ProfileThemesController < BaseController
      before_action :require_profile_customization_ability

      # GET /api/v1/profile_theme
      def show
        theme = current_user.profile_theme_with_defaults
        render json: { data: ProfileThemeSerializer.full(theme, include_draft: true, user: current_user) }
      end

      # PUT /api/v1/profile_theme
      def update
        theme = current_user.profile_theme || current_user.build_profile_theme(
          sections: ProfileTheme.default_sections_for_role(current_user.role)
        )

        permitted = theme_params

        # Validate sections if provided
        if permitted[:sections].present?
          validator = ProfileThemeValidator.new(current_user, permitted[:sections])
          unless validator.valid?
            return render json: {
              error: "validation_error",
              message: validator.error_messages,
              details: validator.errors
            }, status: :unprocessable_entity
          end

          # Sections go to draft, not directly to published
          theme.draft_sections = permitted[:sections]
        end

        # Validate single_post_layout if provided
        if permitted[:single_post_layout].present?
          validator = SinglePostLayoutValidator.new(permitted[:single_post_layout])
          unless validator.valid?
            return render json: {
              error: "validation_error",
              message: validator.error_messages,
              details: validator.errors
            }, status: :unprocessable_entity
          end

          # Single post layout goes to draft, not directly to published
          theme.draft_single_post_layout = permitted[:single_post_layout]
        end

        # Validate pages if provided
        if permitted[:pages].present?
          validator = ProfilePageValidator.new(permitted[:pages])
          unless validator.valid?
            return render json: {
              error: "validation_error",
              message: validator.error_messages,
              details: validator.errors
            }, status: :unprocessable_entity
          end

          # Pages go to draft, not directly to published
          theme.draft_pages = permitted[:pages]
        end

        # Update other theme attributes directly
        theme.assign_attributes(permitted.except(:sections, :single_post_layout, :pages))

        if theme.save
          render json: { data: ProfileThemeSerializer.full(theme, include_draft: true, user: current_user) }
        else
          render json: {
            error: "validation_error",
            message: theme.errors.full_messages.join(', '),
            details: theme.errors.messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/profile_theme/publish
      def publish
        theme = current_user.profile_theme
        unless theme
          return render json: { error: "not_found", message: "No profile theme found" }, status: :not_found
        end

        unless theme.has_draft?
          # No draft — return current published theme as success (idempotent)
          return render json: { data: ProfileThemeSerializer.full(theme, include_draft: true, user: current_user), message: "No draft changes to publish" }
        end

        # Validate draft sections before publishing
        if theme.draft_sections.present?
          validator = ProfileThemeValidator.new(current_user, theme.draft_sections)
          unless validator.valid?
            return render json: {
              error: "validation_error",
              message: validator.error_messages,
              details: validator.errors
            }, status: :unprocessable_entity
          end
        end

        # Validate draft single post layout before publishing
        if theme.draft_single_post_layout.present?
          validator = SinglePostLayoutValidator.new(theme.draft_single_post_layout)
          unless validator.valid?
            return render json: {
              error: "validation_error",
              message: validator.error_messages,
              details: validator.errors
            }, status: :unprocessable_entity
          end
        end

        # Validate draft pages before publishing
        if theme.draft_pages.present?
          validator = ProfilePageValidator.new(theme.draft_pages)
          unless validator.valid?
            return render json: {
              error: "validation_error",
              message: validator.error_messages,
              details: validator.errors
            }, status: :unprocessable_entity
          end
        end

        theme.publish!
        sync_links_from_sections(theme.sections)
        render json: { data: ProfileThemeSerializer.full(theme, include_draft: true, user: current_user), message: "Theme published successfully" }
      end

      # POST /api/v1/profile_theme/discard_draft
      def discard_draft
        theme = current_user.profile_theme
        unless theme
          return render json: { error: "not_found", message: "No profile theme found" }, status: :not_found
        end

        unless theme.has_draft?
          return render json: { error: "no_draft", message: "No draft to discard" }, status: :unprocessable_entity
        end

        theme.discard_draft!
        render json: { data: ProfileThemeSerializer.full(theme, include_draft: true, user: current_user), message: "Draft discarded" }
      end

      # POST /api/v1/profile_theme/reset
      def reset
        theme = current_user.profile_theme || current_user.create_profile_theme!(
          sections: ProfileTheme.default_sections_for_role(current_user.role)
        )

        theme.reset_to_defaults!
        render json: { data: ProfileThemeSerializer.full(theme, include_draft: true, user: current_user), message: "Theme reset to defaults" }
      end

      private

      def require_profile_customization_ability
        require_ability!(:can_customize_profile)
      end

      # Sync social/streaming links from published hero section back to user/band models
      def sync_links_from_sections(sections)
        hero = sections.find { |s| (s['type'] || s[:type]) == 'hero' }
        return unless hero

        content = hero['content'] || hero[:content] || {}

        sync_social_links(content['social_links'] || content[:social_links])
        sync_streaming_links(content['streaming_links'] || content[:streaming_links])
      end

      SOCIAL_LINK_COLUMNS = {
        'instagram' => :instagram_url,
        'threads' => :threads_url,
        'bluesky' => :bluesky_url,
        'twitter' => :twitter_url,
        'tumblr' => :tumblr_url,
        'tiktok' => :tiktok_url,
        'facebook' => :facebook_url,
        'youtube' => :youtube_url
      }.freeze

      STREAMING_LINK_COLUMNS = {
        'spotify' => :spotify_link,
        'appleMusic' => :apple_music_link,
        'bandcamp' => :bandcamp_link,
        'soundcloud' => :soundcloud_link,
        'youtubeMusic' => :youtube_music_link
      }.freeze

      def sync_social_links(social_links)
        return unless social_links.is_a?(Hash)

        # Social links live on user for bloggers, band for band accounts
        target = current_user.band? ? current_user.primary_band : current_user
        return unless target

        updates = {}
        SOCIAL_LINK_COLUMNS.each do |platform, column|
          next unless target.respond_to?(column)
          updates[column] = social_links[platform].presence
        end

        target.update(updates) if updates.any?
      end

      def sync_streaming_links(streaming_links)
        return unless streaming_links.is_a?(Hash)

        band = current_user.primary_band
        return unless band

        updates = {}
        STREAMING_LINK_COLUMNS.each do |platform, column|
          next unless band.respond_to?(column)
          updates[column] = streaming_links[platform].presence
        end

        band.update(updates) if updates.any?
      end

      def theme_params
        # Handle both wrapped (profile_theme: {...}) and unwrapped params
        source = params[:profile_theme].present? ? params[:profile_theme] : params

        result = {}

        # Extract simple fields (explicitly whitelisted)
        %w[background_color brand_color font_color header_font body_font content_max_width card_background_opacity border_radius].each do |field|
          result[field] = source[field] if source[field].present?
        end

        # Nullable fields — accept nil/"" to clear the value
        %w[card_background_color].each do |field|
          if source.key?(field)
            value = source[field]
            result[field] = value.present? ? value : nil
          end
        end

        # Handle sections - convert to array of hashes with sanitized content/settings
        if source[:sections].present?
          result[:sections] = source[:sections].map do |section|
            section_hash = {
              'type' => section[:type],
              'visible' => section[:visible],
              'order' => section[:order]
            }
            section_hash['content'] = sanitize_json(section[:content]) if section[:content].present?
            section_hash['settings'] = sanitize_json(section[:settings]) if section[:settings].present?
            section_hash
          end
        end

        # Handle single_post_layout - flat hash of settings
        if source[:single_post_layout].present?
          result[:single_post_layout] = sanitize_json(source[:single_post_layout])
        end

        # Handle pages - array of page configs
        if source[:pages].present?
          result[:pages] = source[:pages].map do |page|
            page_hash = {
              'type' => page[:type],
              'slug' => page[:slug],
              'visible' => page[:visible]
            }
            page_hash['settings'] = sanitize_json(page[:settings]) if page[:settings].present?
            page_hash
          end
        end

        result
      end

      # Recursively convert params to plain Ruby hash, allowing only JSON-safe types.
      # This replaces to_unsafe_h + permit! while keeping content/settings flexible
      # for the evolving site builder schema.
      def sanitize_json(value, depth: 0)
        raise ActionController::BadRequest, "Nested data too deep" if depth > 5

        case value
        when ActionController::Parameters
          value.keys.each_with_object({}) do |key, hash|
            hash[key.to_s] = sanitize_json(value[key], depth: depth + 1)
          end
        when Hash
          value.each_with_object({}) do |(k, v), hash|
            hash[k.to_s] = sanitize_json(v, depth: depth + 1)
          end
        when Array
          value.map { |v| sanitize_json(v, depth: depth + 1) }
        when String, Integer, Float, TrueClass, FalseClass, NilClass
          value
        else
          nil # Strip anything that isn't JSON-safe
        end
      end
    end
  end
end
