class FollowsController < BaseController
  def index
    @current_acc = CommunityAdmin.where(patchwork_community_id: session[:form_data]['id']).first.account_id
    @records = load_records
    @search = records_filter.build_search
    respond_to do |format|
      format.html { render partial: 'follows/search_result', locals: { records: @records } }
    end
  end

  protected

  def records_filter
    @filter = Filter::Account.new(params)
  end
end