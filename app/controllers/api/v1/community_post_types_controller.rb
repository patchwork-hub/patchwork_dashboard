module Api
  module V1
    class CommunityPostTypesController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_user_from_header
      before_action :set_community

      def index
        authorize @community, :index?
        @community_post_type = @community.community_post_type
        if @community_post_type
          render json: {
            posts: @community_post_type.posts,
            reposts: @community_post_type.reposts,
            replies: @community_post_type.replies
          }
        else
          render json: {
            posts: false,
            reposts: false,
            replies: false
          }
        end
      end

      def create
        @community_post_type = @community.community_post_type || @community.build_community_post_type
        @community_post_type.assign_attributes(community_post_type_params)
        if @community_post_type.save
          if @community_post_type.previous_changes.present?
            render json: { message: "Community post type preferences saved successfully!" }, status: :ok
          else
            render json: { message: "Community post type preferences created successfully!" }, status: :created
          end
        else
          render json: { errors: @community_post_type.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_community
        @community = Community.find(params[:community_id])
      end

      def community_post_type_params
        params.require(:community_post_type).permit(:posts, :reposts, :replies)
      end
    end
  end
end
