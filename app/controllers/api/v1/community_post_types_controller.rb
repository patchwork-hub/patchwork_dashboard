module Api
  module V1
    class CommunityPostTypesController < ApplicationController
      before_action :set_community

      def show
        @community_post_type = @community.community_post_type
        if @community_post_type
          render json: {
            posts: @community_post_type.posts,
            reposts: @community_post_type.reposts,
            replies: @community_post_type.replies
          }
        else
          render json: { error: "Community post type preferences not found for this community" }, status: :not_found
        end
      end

      def update
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
