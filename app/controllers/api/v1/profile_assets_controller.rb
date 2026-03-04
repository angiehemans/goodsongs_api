# frozen_string_literal: true

module Api
  module V1
    class ProfileAssetsController < BaseController
      before_action :require_profile_customization_ability
      before_action :set_asset, only: [:destroy]

      # GET /api/v1/profile_assets
      def index
        assets = current_user.profile_assets.order(created_at: :desc)
        render json: {
          data: assets.map { |asset| ProfileAssetSerializer.full(asset) },
          meta: {
            total: assets.count,
            limit: ProfileAsset::MAX_ASSETS_PER_USER
          }
        }
      end

      # POST /api/v1/profile_assets
      def create
        asset = current_user.profile_assets.build(asset_params)

        if asset.save
          render json: { data: ProfileAssetSerializer.full(asset) }, status: :created
        else
          render json: {
            error: "validation_error",
            message: asset.errors.full_messages.join(', '),
            details: asset.errors.messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/profile_assets/:id
      def destroy
        @asset.destroy
        render json: { message: "Asset deleted successfully" }
      end

      private

      def require_profile_customization_ability
        require_ability!(:can_customize_profile)
      end

      def set_asset
        @asset = current_user.profile_assets.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "not_found", message: "Asset not found" }, status: :not_found
      end

      def asset_params
        params.permit(:image, :purpose)
      end
    end
  end
end
