class CommunityFilterKeywordsController < ApplicationController
  before_action :set_community_filter_keyword, only: [:edit, :update, :destroy]

  def create
    @community_filter_keyword = CommunityFilterKeyword.new(community_filter_keyword_params)
    patchwork_community_id = params.dig(:community_filter_keyword, :patchwork_community_id)
    if @community_filter_keyword.save
      redirect_to step4_community_path(id: patchwork_community_id), notice: 'Keyword filter was successfully created.'
    else
      flash[:error] = 'Error creating keyword filter. Please check your input.'
      redirect_to step4_community_path(id: patchwork_community_id)
    end
  end

  def update
    patchwork_community_id = params.dig(:community_filter_keyword, :patchwork_community_id)
    if @community_filter_keyword.update(community_filter_keyword_params)
      redirect_to step4_community_path(id: patchwork_community_id), notice: 'Keyword filter was successfully updated.'
    else
      flash[:error] = 'Error creating keyword filter. Please check your input.'
      redirect_to step4_community_path(id: patchwork_community_id)
    end
  end

  def destroy
    patchwork_community_id = params[:patchwork_community_id]
    @community_filter_keyword.destroy
    redirect_to step4_community_path(id: patchwork_community_id), notice: 'Keyword filter was successfully deleted.'
  end

  private

  def set_community_filter_keyword
    @community_filter_keyword = CommunityFilterKeyword.find(params[:id])
  end

  def community_filter_keyword_params
    params.require(:community_filter_keyword).permit(:account_id, :patchwork_community_id, :keyword, :is_filter_hashtag)
  end
end
