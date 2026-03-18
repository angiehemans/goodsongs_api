# frozen_string_literal: true

module Api
  module V1
    class ProfileLinksController < BaseController
      before_action :require_profile_customization_ability
      before_action :set_profile_link, only: [:update, :destroy]

      # GET /api/v1/profile_links
      def index
        links = current_user.profile_links.ordered
        render json: { data: links.map { |l| serialize_link(l) } }
      end

      # POST /api/v1/profile_links
      def create
        link = current_user.profile_links.build(link_params)

        # Auto-assign position if not provided
        if link.position == 0 && !params.key?(:position)
          max_position = current_user.profile_links.maximum(:position) || -1
          link.position = max_position + 1
        end

        if link.save
          render json: { data: serialize_link(link) }, status: :created
        else
          render json: {
            error: "validation_error",
            message: link.errors.full_messages.join(', '),
            details: link.errors.messages
          }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/profile_links/:id
      def update
        # Handle thumbnail removal
        if params[:remove_thumbnail].present?
          @link.thumbnail.purge if @link.thumbnail.attached?
        end

        if @link.update(link_params.except(:remove_thumbnail))
          render json: { data: serialize_link(@link) }
        else
          render json: {
            error: "validation_error",
            message: @link.errors.full_messages.join(', '),
            details: @link.errors.messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/profile_links/:id
      def destroy
        @link.destroy!
        render json: { message: "Link deleted" }
      end

      # PUT /api/v1/profile_links/reorder
      def reorder
        link_ids = params[:link_ids]

        unless link_ids.is_a?(Array)
          return render json: { error: "validation_error", message: "link_ids must be an array" }, status: :unprocessable_entity
        end

        user_link_ids = current_user.profile_links.pluck(:id)
        unless (link_ids.map(&:to_i) - user_link_ids).empty?
          return render json: { error: "validation_error", message: "All link_ids must belong to the current user" }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          link_ids.each_with_index do |id, index|
            current_user.profile_links.where(id: id).update_all(position: index)
          end
        end

        links = current_user.profile_links.ordered
        render json: { data: links.map { |l| serialize_link(l) } }
      end

      private

      def require_profile_customization_ability
        require_ability!(:can_customize_profile)
      end

      def set_profile_link
        @link = current_user.profile_links.find(params[:id])
      end

      def link_params
        params.permit(:title, :url, :icon, :description, :position, :visible, :thumbnail, :remove_thumbnail)
      end

      def serialize_link(link)
        {
          id: link.id,
          title: link.title,
          description: link.description,
          url: link.url,
          icon: link.icon,
          position: link.position,
          visible: link.visible,
          thumbnail_url: link.thumbnail_url,
          created_at: link.created_at,
          updated_at: link.updated_at
        }
      end
    end
  end
end
