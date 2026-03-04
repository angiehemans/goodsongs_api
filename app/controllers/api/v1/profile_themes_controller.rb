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

        # Update other theme attributes directly
        theme.assign_attributes(permitted.except(:sections))

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
          return render json: { error: "no_draft", message: "No draft to publish" }, status: :unprocessable_entity
        end

        # Validate draft sections before publishing
        validator = ProfileThemeValidator.new(current_user, theme.draft_sections)
        unless validator.valid?
          return render json: {
            error: "validation_error",
            message: validator.error_messages,
            details: validator.errors
          }, status: :unprocessable_entity
        end

        theme.publish!
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

      def theme_params
        # Handle both wrapped (profile_theme: {...}) and unwrapped params
        source = params[:profile_theme].present? ? params[:profile_theme] : params

        result = {}

        # Extract simple fields
        %w[background_color brand_color font_color header_font body_font].each do |field|
          result[field] = source[field] if source[field].present?
        end

        # Handle sections - convert to array of hashes
        if source[:sections].present?
          result[:sections] = source[:sections].map do |section|
            section_hash = {
              'type' => section[:type],
              'visible' => section[:visible],
              'order' => section[:order]
            }
            section_hash['content'] = section[:content].to_unsafe_h if section[:content].present?
            section_hash['settings'] = section[:settings].to_unsafe_h if section[:settings].present?
            section_hash
          end
        end

        ActionController::Parameters.new(result).permit!
      end
    end
  end
end
