class CommunitiesController < BaseController
  skip_before_action :handle_authentication
  before_action :handle_authentication_cookies
  before_action :set_community, except: %i[step1 step1_save index new is_muted]
  before_action :initialize_form, only: %i[step1]
  before_action :set_current_step
  before_action :set_content_type, only: %i[step3 step4 step5 step6]
  before_action :set_api_credentials, only: %i[search_contributor step3 step3_save step3_update_hashtag step3_delete_hashtag step4]
  before_action :fetch_community_admins, only: %i[step4 step6]
  PER_PAGE = 10

  def index
    @channel_type = params[:channel_type] || default_channel_type
    @records = records_filter.get.where(channel_type: @channel_type)
    @search = records_filter.build_search
  end

  def step1
    respond_to do |format|
      format.html
    end
  end

  def step1_save
    id = form_params[:id].presence
    @community = CommunityPostService.new.call(
      current_user,
      id: id,
      name: form_params[:name],
      slug: form_params[:slug],
      bio: form_params[:bio],
      collection_id: form_params[:collection_id],
      banner_image: form_params[:banner_image],
      avatar_image: form_params[:avatar_image],
      logo_image: form_params[:logo_image],
      community_type_id: form_params[:community_type_id],
      is_recommended: form_params[:is_recommended]
    )

    if @community.errors.any?
      @community_form = Form::Community.new(form_params)
      flash.now[:error] = @community.errors.full_messages
      render :step1
    else
      redirect_to step2_community_path(@community)
    end
  end

  def step2
    @records = load_commu_admin_records
    @community_admin = CommunityAdmin.new
  end

  def step3
    @records = load_commu_hashtag_records
    @search = commu_hashtag_records_filter.build_search
    @community_hashtag_form = Form::CommunityHashtag.new
    @follow_records = load_follow_records
    @filter_keywords = get_community_filter_keyword('filter_in')
    @community_filter_keyword = CommunityFilterKeyword.new(
      patchwork_community_id: @community.id,
      filter_type: 'filter_in',
      is_filter_hashtag: false
    )
  end

  def step3_save
    begin
      perform_hashtag_action(community_hashtag_params[:hashtag].gsub('#', ''), community_hashtag_params[:community_id], :follow)
      flash[:notice] = "Hashtag saved successfully!"
    rescue CommunityHashtagPostService::InvalidHashtagError => e
      flash[:error] = e.message
    rescue ActiveRecord::RecordNotUnique => e
      flash[:error] = "Duplicate entry: Hashtag already exists."
    end

    redirect_to step3_community_path
  end

  def step3_update_hashtag
    begin
      community_hashtag = CommunityHashtag.find(params[:form_community_hashtag][:hashtag_id])

      perform_hashtag_action(community_hashtag.hashtag, nil, :unfollow)

      community_hashtag.update!(hashtag: params[:form_community_hashtag][:hashtag].gsub('#', ''))
      perform_hashtag_action(community_hashtag.hashtag, nil, :follow)

      flash[:notice] = "Hashtag updated successfully!"
    rescue CommunityHashtagPostService::InvalidHashtagError => e
      flash[:error] = e.message
    rescue ActiveRecord::RecordNotUnique => e
      flash[:error] = "Duplicate entry: Hashtag already exists."
    end

    redirect_to step3_community_path
  end

  def step3_delete_hashtag
    hashtag = CommunityHashtag.find(params[:community_hashtag_id])

    if hashtag.destroy
      perform_hashtag_action(hashtag.hashtag, nil, :unfollow)
      flash[:notice] = "Hashtag removed successfully!"
    else
      flash[:error] = "Failed to remove hashtag."
    end
    redirect_to step3_community_path(params[:id])
  end

  def step4
    @muted_accounts = get_muted_accounts
    @community_post_type = CommunityPostType.find_or_initialize_by(patchwork_community_id: @community.id)

    @filter_keywords = get_community_filter_keyword('filter_out')
    @community_filter_keyword = CommunityFilterKeyword.new(
      patchwork_community_id: @community.id,
      filter_type: 'filter_out'
    )
  end

  def step4_save
    @community_post_type = CommunityPostType.find_or_initialize_by(patchwork_community_id: @community.id)
    if @community_post_type.update(community_post_type_params)
      flash[:notice] = "Community post type preferences saved successfully!"
      redirect_to step4_community_path
    else
      flash[:error] = "Failed to save post type preferences."
      render :step4
    end
  end

  def step5
    authorize @community, :step5?
    @form_post_hashtag = Form::PostHashtag.new
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    respond_to do |format|
      format.html
    end
  end

  def step5_delete
    authorize @community, :step5_delete?
    PostHashtag.find(params[:post_hashtag_id].to_i).destroy
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    redirect_to step5_community_path
  end

  def step5_update
    authorize @community, :step5_update?
    UpdateHashtagService.new.call(params[:form_post_hashtag])
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    redirect_to step5_community_path
  end

  def step5_save
    authorize @community, :step5_save?
    PostHashtagService.new.call(post_hashtag_params)
    @records = load_post_hashtag_records
    @search = post_hashtag_records_filter.build_search
    redirect_to step5_community_path
  end

  def step6
    authorize @community, :step6?
    @admin = Account.where(id: get_community_admin_id).first
  end

  def manage_additional_information
    authorize @community, :manage_additional_information?
    if params[:community].present?
      if @community.update(community_params)
        respond_to do |format|
          format.html
        end
      else
        respond_to do |format|
          format.html { redirect_to step6_community_path, alert: 'Failed to save information.' }
          format.js
        end
      end
    end
  end

  def set_visibility
    visibility = params.dig(:community, :visibility).presence || 'public_access'
    if @community.update(visibility: visibility)
      # admin_email = User.where(account_id: get_community_admin_id)
      # DashboardMailer.channel_created(@community, admin_email).deliver_now
      if @community.channel?
        CreateCommunityInstanceDataJob.perform_later(@community.id, @community.slug) if ENV['ALLOW_CHANNELS_CREATION'] == 'true'
        redirect_to communities_path(channel_type: 'channel')
      else
        redirect_to communities_path(channel_type: 'channel_feed')
      end
    else
      if @community.channel?
        render :step6
      else
        render :step4
      end
    end
  end

  def new
    respond_to do |format|
      format.html
    end
  end

  def search_contributor
    query = params[:query]

    result = ContributorSearchService.new(query, url: @api_base_url, token: @token).call

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
    Mute.find_by(account_id: get_community_admin_id, target_account_id: target_account_id)&.destroy

    redirect_to step4_community_path
  end

  def is_muted
    target_account_id = params[:account_id]
    is_muted = Mute.exists?(account_id: get_community_admin_id, target_account_id: target_account_id)

    render json: { is_muted: is_muted }
  end

  private

  def initialize_form
    if params[:id].present? || (params[:form_community] && params[:form_community][:id].present?)
      id = params[:id] || params[:form_community][:id]
      @community = Community.find_by(id: id)
      authorize @community, :initialize_form?
      if @community.present?

        form_data = {
          id: @community.id,
          name: @community.name,
          slug: @community.slug,
          bio: @community.description,
          collection_id: @community.patchwork_collection_id,
          banner_image: @community.banner_image,
          avatar_image: @community.avatar_image,
          logo_image: @community.logo_image,
          community_type_id: @community.patchwork_community_type_id,
          is_recommended: @community.is_recommended
        }
      else
        form_data = {}
      end
    else
      form_data = {}
    end

    @community_form = Form::Community.new(form_data)
  end

  def fetch_community_admins
    @community_admins = CommunityAdmin.where(patchwork_community_id: @community.id)
  end

  def post_hashtag_params
    params.require(:form_post_hashtag).permit(:hashtag1, :hashtag2, :hashtag3, :community_id)
  end

  def community_hashtag_params
    params.require(:form_community_hashtag).permit(:community_id, :hashtag)
  end

  def form_params
    params.require(:form_community).permit(:id, :name, :slug, :collection_id, :bio, :banner_image, :avatar_image, :logo_image, :community_type_id, :is_recommended)
  end

  def community_params
    params.require(:community).permit(
      patchwork_community_additional_informations_attributes: [:id, :heading, :text, :_destroy],
      patchwork_community_links_attributes: [:id, :icon, :name, :url, :_destroy],
      patchwork_community_rules_attributes: [:id, :rule, :_destroy]
    )
  end

  def community_post_type_params
    params.require(:community_post_type).permit(:posts, :reposts, :replies)
  end

  def records_filter
    Filter::Community.new(params, current_user)
  end

  def load_commu_admin_records
    commu_admin_records_filter.get
  end

  def load_commu_hashtag_records
    commu_hashtag_records_filter.get
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

  def get_community_filter_keyword(filter_type)
    CommunityFilterKeyword.where(patchwork_community_id: @community.id, filter_type: filter_type).page(params[:page]).per(PER_PAGE)
  end

  def get_community_admin_id
    CommunityAdmin.where(patchwork_community_id: @community.id, is_boost_bot: true).pluck(:account_id).first
  end

  def get_muted_accounts
    admin_account_id = get_community_admin_id
    muted_account_ids = Mute.where(account_id: admin_account_id).pluck(:target_account_id)
    Account.where(id: muted_account_ids).page(params[:page]).per(PER_PAGE)
  end

  def set_community
    @community = Community.find(params[:id])
    authorize @community, :initialize_form?
    raise ActiveRecord::RecordNotFound unless @community
  end

  def set_content_type
    @content_type = @community.content_type
  end

  def set_api_credentials
    @api_base_url = ENV['MASTODON_INSTANCE_URL']
    @token = fetch_oauth_token
  end

  def fetch_oauth_token
    admin = Account.where(id: get_community_admin_id).first
    if admin
      token_service = GenerateAdminAccessTokenService.new(admin.user.id)
      token_service.call
    end
  end

  def perform_hashtag_action(hashtag_name, community_id = nil, action)
    if action == :follow && community_id
      CommunityHashtagPostService.new.call(get_community_admin_id, hashtag: hashtag_name, community_id: community_id)
    end

    hashtag = SearchHashtagService.new(@api_base_url, @token, hashtag_name).call
    return puts "Hashtag not found" unless hashtag

    service_class = action == :follow ? FollowHashtagService : UnfollowHashtagService
    result = service_class.new(@api_base_url, @token, hashtag[:name]).call
    puts result ? "Successfully #{action}ed ##{hashtag[:name]}" : "Failed to #{action} ##{hashtag[:name]}"
  end

  def default_channel_type
    current_user.user_admin? ? 'channel_feed' : 'channel'
  end

  def set_current_step
    @current_step = action_name.match(/\d+/).to_s.to_i || 1
  end
end
