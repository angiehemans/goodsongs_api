# frozen_string_literal: true

module Api
  module V1
    class DirectUploadsController < BaseController
      before_action :authenticate_request

      def create
        blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_params)
        render json: {
          blob_id: blob.signed_id,
          key: blob.key,
          direct_upload: {
            url: blob.service_url_for_direct_upload,
            headers: blob.service_headers_for_direct_upload
          }
        }
      end

      private

      def blob_params
        params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type)
          .to_h.symbolize_keys
      end
    end
  end
end
