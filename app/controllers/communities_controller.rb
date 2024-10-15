class CommunitiesController < BaseController
  before_action :set_community, only: %i[step2 contributors_table step3 step4 step4_save step5 step5_delete step5_update step5_save step6 set_visibility manage_additional_information]
  before_action :initialize_form, expect: %i[index]
  before_action :set_current_step, except: %i[show]
  PER_PAGE = 10

  def step1
    respond_to do |format|
      format.html
    end
  end

  def step1_save
    id = form_params[:id].presence
    @community = CommunityPostService.new.call(
      @current_user.account,
      id: id,
      name: form_params[:name],
      bio: form_params[:bio],
      collection_id: form_params[:collection_id],
      banner_image: form_params[:banner_image],
      avatar_image: form_params[:avatar_image]
    )

    if @community.errors.any?
      @community_form = Form::Community.new(form_params)
      flash.now[:error] = @community.errors.full_messages.join(', ')
      render :step1
    else
      redirect_to step2_community_path(@community)
    end
  end

  def step2
    @records = load_commu_admin_records
    @new_admin_form = Form::CommunityAdmin.new
    @edit_admin = Account.find_by(id: CommunityAdmin.find_by(id: params[:admin_id])&.account_id) || Account.new

    @edit_admin_form = Form::CommunityAdmin.new(
      community_id: @community.id,
      display_name: @edit_admin&.display_name,
      username: @edit_admin&.username
    )

    respond_to do |format|
      format.html
      format.json { render json: {admin_id: @edit_admin.id.to_s, display_name: @edit_admin.display_name, username: @edit_admin.username } }
    end
  end

  def step2_save
    @community_admin = CommunityAdminPostService.new.call(
    @current_user.account,
    community_id: new_admin_form_params[:community_id],
    display_name: new_admin_form_params[:display_name],
    username: new_admin_form_params[:username],
    email: new_admin_form_params[:email],
    password: new_admin_form_params[:password])

    redirect_to step2_community_path
  end

  def step2_update_admin
    @community_admin = Account.find_by_id(params[:form_community_admin][:admin_id])
    if @community_admin.update(admin_params)
      redirect_to step2_community_path(@community.id), notice: 'Admin updated successfully'
    else
      @records = load_commu_admin_records
      render :step2
    end
  end

  def step3
    @records = load_commu_hashtag_records
    @search = commu_hashtag_records_filter.build_search
    @community_hashtag_form = Form::CommunityHashtag.new
    @community_admin = get_community_admin_id
    @follow_records = load_follow_records
    @follower_search = commu_contributors_filter.build_search

    respond_to do |format|
      format.html
    end
  end

  def step3_save
    begin
      CommunityHashtagPostService.new.call(@community.community_admins&.first.account,
                                           hashtag: community_hashtag_params[:hashtag],
                                           community_id: community_hashtag_params[:community_id])
      flash[:success] = "Hashtag saved successfully!"
      redirect_to step3_community_path
    rescue CommunityHashtagPostService::InvalidHashtagError => e
      flash[:error] = e.message
      redirect_to step3_community_path
    end
  end

  def step3_update_hashtag
    community_hashtag = CommunityHashtag.find(params[:form_community_hashtag][:hashtag_id])
    community_hashtag.update!(hashtag: params[:form_community_hashtag][:hashtag].gsub('#', ''))
    flash[:success] = "Hashtag updated successfully!"
    redirect_to step3_community_path
  end

  def step3_delete_hashtag
    hashtag = CommunityHashtag.find(params[:community_hashtag_id])
    if hashtag.destroy
      flash[:success] = "Hashtag removed successfully!"
    else
      flash[:error] = "Failed to remove hashtag."
    end
    redirect_to step3_community_path(params[:id])
  end

  def step4
    @filter_keywords = get_community_filter_keyword
    admin_id = get_community_admin_id
    @muted_accounts = get_muted_accounts
    @community_post_type = CommunityPostType.find_or_initialize_by(patchwork_community_id: @community.id)
    @community_filter_keyword = CommunityFilterKeyword.new(
      patchwork_community_id: @community.id,
      account_id: admin_id
    )

    respond_to do |format|
      format.html
    end
  end

  def step4_save
    @community_post_type = CommunityPostType.find_or_initialize_by(patchwork_community_id: @community.id)

    if @community_post_type.update(community_post_type_params)
      flash[:success] = "Community post type preferences saved successfully!"
      redirect_to step4_community_path
    else
      flash[:error] = "Failed to save post type preferences."
      render :step4
    end
  end

  def step5
    @form_post_hashtag = Form::PostHashtag.new
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    respond_to do |format|
      format.html
    end
  end

  def step5_delete
    PostHashtag.find(params[:post_hashtag_id].to_i).destroy
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    redirect_to step5_community_path
  end

  def step5_update
    UpdateHashtagService.new.call(params[:form_post_hashtag])
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    redirect_to step5_community_path
  end

  def step5_save
    PostHashtagService.new.call(post_hashtag_params)
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    redirect_to step5_community_path
  end

  def step6
    @rule_from = Form::CommunityRule.new
    @rule_records = CommunityRule.where(patchwork_community_id: @community.id)
    @aditional_information = @community.patchwork_community_additional_informations
    @community_admins = Account.joins(:community_admins).where(community_admins: { patchwork_community_id: @community.id })
  end

  def step6_rule_create
    CommunityRuleService.new.call(params[:form_community_rule])
    redirect_to step6_community_path
  end

  def set_visibility
    visibility = params.dig(:community, :visibility).presence || 'public_access'
    if @community.update(visibility: visibility)
      # admin_email = User.where(account_id: get_community_admin_id)
      # DashboardMailer.channel_created(@community, admin_email).deliver_now
      CreateCommunityInstanceDataJob.perform_later(@community.id, @community.slug) if ENV['ALLOW_CHANNELS_CREATION'] == 'true'
      redirect_to communities_path
    else
      render :step6
    end
  end

  def new
    respond_to do |format|
      format.html
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @community, serializer: REST::CommunitySerializer }
    end
  end

  def search_contributor
    query = params[:query]
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    token = fetch_oauth_token || ENV['MASTODON_APPLICATION_TOKEN']

    result = ContributorSearchService.new(query, url: api_base_url, token: token).call

    if result.any?
      render json: { 'accounts' => result }
    else
      render json: { message: 'No saved accounts found', 'accounts' => [] }
    end
  end

  def mute_contributor
    target_account_id = params[:account_id]
    admin_account_id = get_community_admin_id
    mute = params[:mute]
    if mute
      Mute.find_or_create_by!(account_id: admin_account_id, target_account_id: target_account_id, hide_notifications: true)
    else
      Mute.find_by(account_id: admin_account_id, target_account_id: target_account_id)&.destroy
    end

    render json: { success: true }
  end

  def unmute_contributor
    target_account_id = params[:account_id]
    admin_account_id = get_community_admin_id
    Mute.find_by(account_id: admin_account_id, target_account_id: target_account_id)&.destroy

    redirect_to step4_community_path
  end

  def is_muted
    target_account_id = params[:account_id]
    admin_account_id = get_community_admin_id
    is_muted = Mute.exists?(account_id: admin_account_id, target_account_id: target_account_id)

    render json: { is_muted: is_muted }
  end

  def manage_additional_information
    if params[:community].present? && params[:community][:patchwork_community_additional_informations_attributes].present?
      if @community.update(community_params)
        flash[:success] = "Additional information added successfully!"
        redirect_to step6_community_path and return
      else
        flash[:error] = "Failed to save additional information!"
        redirect_to step6_community_path and return
      end
    end
    flash[:error] = "No information to save!"
    redirect_to step6_community_path and return
  end

  private

  def initialize_form
    if params[:id].present? || (params[:form_community] && params[:form_community][:id].present?)
      id = params[:id] || params[:form_community][:id]
      @community = Community.find_by(id: id)

      if @community.present?
        form_data = {
          id: @community.id,
          name: @community.name,
          bio: @community.description,
          collection_id: @community.patchwork_collection_id,
          banner_image: @community.banner_image,
          avatar_image: @community.avatar_image
        }
      else
        form_data = {}
      end
    else
      form_data = {}
    end

    @community_form = Form::Community.new(form_data)
  end

  def fetch_oauth_token
    admin = @community.community_admins&.first.account

    token_service = GenerateAdminAccessTokenService.new(admin.user.id)
    token_service.call
  end

  def post_hashtag_params
    params.require(:form_post_hashtag).permit(:hashtag1, :hashtag2, :hashtag3, :community_id)
  end

  def community_hashtag_params
    params.require(:form_community_hashtag).permit(:community_id, :hashtag)
  end

  def form_params
    params.require(:form_community).permit(:id, :name, :collection_id, :bio, :banner_image, :avatar_image)
  end

  def new_admin_form_params
    params.require(:form_community_admin).permit(:community_id, :display_name, :username, :email, :password)
  end

  def admin_params
    params.require(:form_community_admin).permit(:display_name, :username)
  end

  def community_params
    params.require(:community).permit(
      patchwork_community_additional_informations_attributes: [:id, :heading, :text, :_destroy]
    )
  end

  def community_post_type_params
    params.require(:community_post_type).permit(:posts, :reposts, :replies)
  end

  def records_filter
    Filter::Community.new(params)
  end

  def load_commu_admin_records
    commu_admin_records_filter.get
  end

  def load_commu_hashtag_records
    commu_hashtag_records_filter.get
  end

  def load_contributors_records
    commu_contributors_filter.get
  end

  def load_post_hashtag_records
    post_hashtag_records_filter.get
  end

  def load_commu_follower_records
    commu_follower_filter.get
  end

  def load_follow_records
    account_id = get_community_admin_id
    follow_ids = Follow.where(account_id: account_id).pluck(:target_account_id)
    follow_request_ids = FollowRequest.where(account_id: account_id).pluck(:target_account_id)
    total_follows_ids = follow_ids + follow_request_ids
    Account.where(id: total_follows_ids).page(params[:page]).per(PER_PAGE)
  end

  def commu_follower_filter
    @follower_filter = Filter::Account.new(params)
  end

  def commu_contributors_filter
    params[:q] = { account_id_eq: @community.community_admins&.first&.account_id }
    @contributor_filter = Filter::Follow.new(params)
  end

  def commu_admin_records_filter
    params[:q] = { patchwork_community_id_eq: @community.id }
    @filter = Filter::CommunityAdmin.new(params)
  end

  def post_hashtag_records_filter
    params[:q] = { patchwork_community_id_eq: @community.id }
    @filter = Filter::PostHashtag.new(params)
  end

  def commu_hashtag_records_filter
    params[:q] = { patchwork_community_id_eq: @community.id }
    Filter::CommunityHashtag.new(params)
  end

  def get_community_filter_keyword
    CommunityFilterKeyword.where(patchwork_community_id: @community.id).page(params[:page]).per(PER_PAGE)
  end

  def get_community_admin_id
    CommunityAdmin.where(patchwork_community_id: params[:id]).first.account_id
  end

  def get_muted_accounts
    admin_account_id = get_community_admin_id
    muted_account_ids = Mute.where(account_id: admin_account_id).pluck(:target_account_id)
    Account.where(id: muted_account_ids).page(params[:page]).per(PER_PAGE)
  end

  def set_community
    @community = Community.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @community
  end

  def set_current_step
    @current_step = action_name.match(/\d+/).to_s.to_i || 1
  end
end
