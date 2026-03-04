# frozen_string_literal: true

module Api
  module V1
    class ProfilesController < BaseController
      skip_before_action :authenticate_request

      # GET /api/v1/profiles/:username
      def show
        user = find_user_by_username
        return render json: { error: "not_found", message: "User not found" }, status: :not_found unless user

        # Fans don't have customizable profiles
        if user.fan?
          return render json: {
            data: UserSerializer.public_profile(user)
          }
        end

        theme = user.profile_theme
        unless theme
          # Return user profile with default sections (no customization)
          return render json: {
            data: build_default_profile_response(user)
          }
        end

        render json: {
          data: build_profile_response(user, theme)
        }
      end

      private

      def find_user_by_username
        User.find_by("lower(username) = ?", params[:username].to_s.downcase)
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
    end
  end
end
