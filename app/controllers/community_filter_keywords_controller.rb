class CommunityFilterKeywordsController < ApplicationController
  before_action :set_community_filter_keyword, only: [:edit, :update, :destroy]

  PER_PAGE = 10
  def index
    @search = fetch_keywords
    @keywords = @search.result.page(params[:page]).per(PER_PAGE)
  end

  def create
    @community_filter_keyword = CommunityFilterKeyword.new(community_filter_keyword_params)
    patchwork_community_id = params.dig(:community_filter_keyword, :patchwork_community_id)

    if @community_filter_keyword.save
      flash[:notice] = 'Keyword filter was successfully created.'
      redirect_to determine_redirect_path(patchwork_community_id, @community_filter_keyword.filter_type)
    else
      flash[:error] = @community_filter_keyword.errors.full_messages
      redirect_to determine_redirect_path(patchwork_community_id, @community_filter_keyword.filter_type)
    end
  end

  def update
    patchwork_community_id = params.dig(:community_filter_keyword, :patchwork_community_id)

    if @community_filter_keyword.update(community_filter_keyword_params)
      flash[:notice] = 'Keyword filter was successfully updated.'
      redirect_to determine_redirect_path(patchwork_community_id, community_filter_keyword_params[:filter_type])
    else
      flash[:error] = @community_filter_keyword.errors.full_messages
      redirect_to determine_redirect_path(patchwork_community_id, community_filter_keyword_params[:filter_type])
    end
  end

  def destroy
    patchwork_community_id = params[:patchwork_community_id]
    @community_filter_keyword.destroy
    flash[:notice] = 'Keyword filter was successfully deleted.'
    redirect_to determine_redirect_path(patchwork_community_id, params[:filter_type])
  end

  private

  def set_community_filter_keyword
    @community_filter_keyword = CommunityFilterKeyword.find(params[:id])
  end

  def community_filter_keyword_params
    params.require(:community_filter_keyword).permit(:patchwork_community_id, :keyword, :is_filter_hashtag, :filter_type)
  end

  def determine_redirect_path(patchwork_community_id, filter_type)
    filter_type == 'filter_in' ? step3_community_path(id: patchwork_community_id) : step4_community_path(id: patchwork_community_id)
  end

  def fetch_keywords
    filter_type = params[:filter_type].to_s.strip
    filter_type = 'filter_out' unless %w[filter_out filter_in].include?(filter_type)

    begin
      community_filter_keywords = CommunityFilterKeyword
                                    .select(:id, :keyword, :filter_type, :is_filter_hashtag, :patchwork_community_id)
                                    .where(
                                      patchwork_community_id: params[:community_id].presence,
                                      filter_type: filter_type
                                    )
                                    .order(:keyword).ransack(params[:q])
      community_filter_keywords
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Error fetching community filter keywords: #{e.message}")
      community_filter_keywords = []
      flash[:error] = 'An error occurred while fetching filter keywords. Please try again later.'
    end
  end
end
