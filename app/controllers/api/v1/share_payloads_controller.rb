# frozen_string_literal: true

module Api
  module V1
    class SharePayloadsController < BaseController
      # GET /api/v1/share_payload?postable_type=review&postable_id=123
      def show
        type = params[:postable_type].to_s.camelize

        unless SharePayloadBuilder::ALLOWED_TYPES.include?(type)
          return render json: { error: "Invalid postable_type" }, status: :unprocessable_entity
        end

        postable = type.constantize.find(params[:postable_id])
        payload = SharePayloadBuilder.new(postable).build

        render json: payload
      end
    end
  end
end
