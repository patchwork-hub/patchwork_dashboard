# app/controllers/api/v1/content_types_controller.rb
module Api
  module V1
    class ContentTypesController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_user_from_header

      def index
        content_types = ContentType.where(patchwork_community_id: params[:patchwork_community_id])
        render json: Api::V1::ContentTypeSerializer.new(content_types).serializable_hash.to_json
      end

      def create
        content_type = ContentType.find_or_initialize_by(patchwork_community_id: content_type_params[:patchwork_community_id])
        content_type.assign_attributes(content_type_params)

        if content_type.save
          render json: Api::V1::ContentTypeSerializer.new(content_type).serializable_hash, status: :ok
        else
          render_validation_failed(content_type.errors)
        end
      end

      private

      def content_type_params
         params.permit(:channel_type, :custom_condition, :patchwork_community_id)
      end
    end
  end
end
