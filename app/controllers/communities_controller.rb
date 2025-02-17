class CommunitiesController < BaseController
  before_action :authenticate_user!
  before_action :set_community, except: %i[step1 step1_save index new is_muted]
  before_action :initialize_form, only: %i[step1]
  before_action :set_current_step
  before_action :set_content_type, only: %i[step3 step4 step5 step6]
  before_action :set_api_credentials, only: %i[search_contributor step3 step4]
  before_action :fetch_community_admins, only: %i[step4 step6]
  PER_PAGE = 10

  def index
    unless params[:channel_type].present?
      redirect_to communities_path(request.query_parameters.merge(channel_type: default_channel_type))
      return
    end
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
      community_type_id: CommunityType.first.id,
      is_recommended: form_params[:is_recommended]
    )

    if @community.errors.any?
      @community_form = Form::Community.new(form_params)
      flash.now[:error] = @community.errors.full_messages
      render :step1
    else
      if current_user.master_admin? || current_user.user_admin?
        redirect_to step2_community_path(@community)
      else
        redirect_to step3_community_path(@community)
      end
    end
  end

  def step2
    authorize @community, :step2?
    @records = load_commu_admin_records
    @community_admin = CommunityAdmin.new
    invoke_bridged
  end

  def step3
    @records = load_commu_hashtag_records
    @search = commu_hashtag_records_filter.build_search
    @community_hashtag_form = Form::CommunityHashtag.new(community_id: @community.id)
    @follow_records = load_follow_records
    @filter_keywords = get_community_filter_keyword('filter_in')
    @community_filter_keyword = CommunityFilterKeyword.new(
      patchwork_community_id: @community.id,
      filter_type: 'filter_in',
      is_filter_hashtag: false
    )
  end

  def step4
    hashtag = load_commu_hashtag_records
    if hashtag.empty?
      flash[:error] = "Please add at least one hashtag in the 'Hashtags' section above before proceeding, as hashtags are required to retrieve content."
      redirect_to step3_community_path
    end
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
      respond_to do |format|
        if params[:community_post_type][:continue] == "true"
          format.js { render js: "window.location = '#{step6_community_path}'" }
        else
          format.js
        end
      end
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
        flash[:error] = @community.errors.full_messages.join(", ")
        redirect_to step6_community_path
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

    result = ContributorSearchService.new(query, url: @api_base_url, token: @token, account_id: get_community_admin_id).call

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
      if @community.present?
        authorize @community, :initialize_form?

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
        authorize current_user, :user_is_not_community_admin?
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
      social_links_attributes: [:id, :icon, :name, :url, :_destroy],
      general_links_attributes: [:id, :icon, :name, :url, :_destroy],
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

  def default_channel_type
    current_user.user_admin? ? 'channel_feed' : 'channel'
  end

  def set_current_step
    @current_step = action_name.match(/\d+/).to_s.to_i || 1
  end

  def invoke_bridged
    @account = CommunityAdmin.find_by(patchwork_community_id: @community.id)&.account
    @bluesky_info = fetch_bluesky_account
  end

  def fetch_bluesky_account
    url = "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=#{@community&.slug}.channel.org"
    response = HTTParty.get(url)
    if response.code == 200
      results = JSON.parse(response.body)
      Rails.logger.info("Fetched bluesky account: #{results}")
      results
    else
      Rails.logger.error("Failed to fetch bluesky account: #{@community&.slug} => #{response.body}")
      {}
    end
  end
end
