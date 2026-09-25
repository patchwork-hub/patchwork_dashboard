class CommunityPostTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_community
  before_action :set_community_post_type

  def create
    create_or_update_post_type
  end

  def update
    create_or_update_post_type
  end

  private

  def set_community
    @community = Community.find(params[:community_id])
  end

  def set_community_post_type
    @community_post_type = @community.community_post_type ||
                           @community.build_community_post_type
  end

  def community_post_type_params
    params.require(:community_post_type).permit(:posts, :reposts, :replies)
  end

  def create_or_update_post_type
    if @community_post_type.update(community_post_type_params)
      handle_success_response
    else
      handle_error_response
    end
  end

  def handle_success_response
    respond_to do |format|
      if params[:continue] == "true"
        next_step_path = @community.channel_feed? ? step5_community_path(@community, channel_type: @community.channel_type) : step6_community_path(@community)
        format.js { render js: "window.location = '#{next_step_path}'" }
      else
        format.js
      end
    end
  end

  def handle_error_response
    respond_to do |format|
      format.js { render partial: 'communities/step4_error' }
    end
  end
end
