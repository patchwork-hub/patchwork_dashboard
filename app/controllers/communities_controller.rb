class CommunitiesController < BaseController
  before_action :authenticate_user!
  before_action :set_community, except: %i[step0 step0_save step1 step1_save index new]
  before_action :initialize_form, only: %i[step0 step1]
  before_action :set_current_step
  before_action :set_content_type, only: %i[step3 step4 step5 step6]
  before_action :set_api_credentials, only: %i[search_contributor step3 step4]
  before_action :fetch_community_admins, only: %i[step4 step6]
  before_action :initial_content_type, only: %i[index step0]

  PER_PAGE = 10
  COMMUNITY_FILTER_TYPES = { in: 'filter_in', out: 'filter_out' }.freeze

  # Main actions
  def index
    params[:channel_type] ||= params[:q].delete(:channel_type)
    redirect_to communities_path(request.query_parameters.merge(channel_type: default_channel_type)) unless params[:channel_type].present?
    @channel_type = params[:channel_type] || default_channel_type
    @records = load_filtered_records(commu_records_filter).where(channel_type: @channel_type)
    @search = commu_records_filter.build_search
  end

  def step0
    id = params[:id]
    if id.present?
      @community = Community.find(id)
      @content_type = @community.content_type
    else
      @content_type = params[:content_type]
    end
    respond_to(&:html)
  end

  def step0_save
    redirect_to step1_new_communities_path(
      channel_type: params[:channel_type],
      content_type: params[:content_type],
      id: params[:id]
    )
  end

  def step1
    respond_to(&:html)
  end

  def step1_save
    @channel_type = @community&.channel_type || params[:channel_type]
    content_type = (current_user.user_admin? || @channel_type == "channel_feed") ?
                    'custom_channel' :
                    (params[:content_type] || @community&.content_type)

    @community = CommunityPostService.new.call(
      current_user,
      form_params.merge(
        community_type_id: 2,
        content_type: content_type,
        channel_type: @channel_type
      )
    )

    if @community.errors.any?
      handle_step1_error(content_type, @channel_type)
    else
      redirect_after_step1_save
    end
  end

  def step2
    authorize_step(:step2?)
    @records = load_filtered_records(commu_admin_records_filter)
    @community_admin = CommunityAdmin.new(patchwork_community_id: @community.id)
    invoke_bridged
  end

  def step3
    @records = load_filtered_records(commu_hashtag_records_filter)
    @search = commu_hashtag_records_filter.build_search
    @community_hashtag_form = Form::CommunityHashtag.new(community_id: @community.id)
    @follow_records = load_follow_records
    setup_filter_keywords(COMMUNITY_FILTER_TYPES[:in])
  end

  def step4
    verify_hashtags_presence
    @muted_accounts = load_muted_accounts
    @community_post_type = @community.community_post_type || new_community_post_type
    setup_filter_keywords(COMMUNITY_FILTER_TYPES[:out])
  end

  def step5
    authorize_step(:step5?)
    @form_post_hashtag = Form::PostHashtag.new
    @records = load_filtered_records(post_hashtag_records_filter)
    @search = post_hashtag_records_filter.build_search
    respond_to(&:html)
  end

  def step6
    authorize_step(:step6?)
    @admin = Account.find_by(id: admin_account_id)
  end

  def manage_additional_information
    authorize @community, :manage_additional_information?
    update_additional_information
  end

  def set_visibility
    if @community.update(visibility: visibility_param)
      handle_successful_visibility_update
    else
      handle_failed_visibility_update
    end
  end

  def new
    respond_to(&:html)
  end

  # Search/mute actions
  def search_contributor
    result = ContributorSearchService.new(
      params[:query],
      url: @api_base_url,
      token: @token,
      account_id: get_community_admin_id
    ).call

    if result.any?
      render json: { 'accounts' => result }
    else
      render json: { message: 'No saved accounts found', 'accounts' => [] }
    end
  end

  def mute_contributor
    handle_mute_action(params[:mute])
    render json: { success: true }
  end

  def unmute_contributor
    unmute_target_account
    redirect_to step4_community_path
  end

  private

  # Before actions
  def set_content_type
    @content_type = @community.content_type
  end

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

  def initial_content_type
    @initial_content_types = [
                        { name: "Broadcast",
                          description: "A broadcast channel is a one-way channel where the account is used to post contents without having the functionality of boosting posts which match the defined hashtag, keywords or followed contributors.",
                          value: "broadcast_channel" },
                        { name: "Group",
                          description: "A group channel is a one-way channel but with the functionality of boosting Following approved users' posts automatically if the post mentions the account of the group channel.",
                          value: "group_channel" },
                        { name: "Curated",
                          description: "A curated channel is a space where content is carefully selected, moderated, or organized by admins before being shared with users.",
                          value: "custom_channel" }
                      ]
  end

  def fetch_community_admins
    @community_admins = CommunityAdmin.where(patchwork_community_id: @community.id)
  end

  # Parameter handling
  def form_params
    params.require(:form_community).permit(
      :id, :name, :slug, :collection_id, :bio,
      :banner_image, :avatar_image, :logo_image,
      :community_type_id, :is_recommended,
      :content_type, :channel_type
    )
  end

  def community_params
    params.require(:community).permit(
      patchwork_community_additional_informations_attributes: [:id, :heading, :text, :_destroy],
      social_links_attributes: [:id, :icon, :name, :url, :_destroy],
      general_links_attributes: [:id, :icon, :name, :url, :_destroy],
      patchwork_community_rules_attributes: [:id, :rule, :_destroy]
    )
  end

  # Setup methods

  # Action handlers

  def handle_step1_error(content_type, channel_type)
    @community_form = Form::Community.new(
      form_params.merge(
        content_type: content_type,
        channel_type: channel_type,
        id: params[:id] || @community.id
      )
    )
    flash.now[:error] = @community.errors.full_messages
    render :step1, status: :unprocessable_entity
  end

  def redirect_after_step1_save
    path = path = (current_user.master_admin? || current_user.user_admin?) ? :step2 : (params[:content_type] == 'custom_channel' ? :step3 : :step6)
    redirect_to send("#{path}_community_path", @community, channel_type: @channel_type)
  end

  def update_additional_information
    if params[:community].blank?
      @community.errors.add(:base, "Missing additional information")
      return handle_update_error(step6_community_path)
    end

    if @community.update(community_params)
      respond_to(&:html)
    else
      handle_update_error(step6_community_path)
    end
  end

  # Filter and load methods
  def load_filtered_records(filter)
    filter.get
  end

  def load_follow_records
    account_ids = Follow.where(account_id: admin_account_id).pluck(:target_account_id) +
                  FollowRequest.where(account_id: admin_account_id).pluck(:target_account_id)
    paginated_records(Account.where(id: account_ids))
  end

  def load_muted_accounts
    muted_ids = Mute.where(account_id: admin_account_id).pluck(:target_account_id)
    paginated_records(Account.where(id: muted_ids))
  end

  # Authorization and verification
  def authorize_step(policy_method)
    authorize @community, policy_method
  end

  def verify_hashtags_presence
    return if load_filtered_records(commu_hashtag_records_filter).any?
    flash[:error] = "Please add at least one hashtag in the 'Hashtags' section above before proceeding, as hashtags are required to retrieve content."
    redirect_to step3_community_path
  end

  # Helper methods
  def setup_filter_keywords(filter_type)
    @filter_keywords = community_filter_keywords(filter_type)
    @community_filter_keyword = CommunityFilterKeyword.new(
      patchwork_community_id: @community.id,
      filter_type: filter_type,
      is_filter_hashtag: filter_type == COMMUNITY_FILTER_TYPES[:in] ? false : nil
    )
  end

  def community_filter_keywords(filter_type)
    paginated_records(CommunityFilterKeyword.where(patchwork_community_id: @community.id, filter_type: filter_type))
  end

  def paginated_records(scope)
    scope.page(params[:page]).per(PER_PAGE)
  end

  def admin_account_id
    @admin_account_id ||= get_community_admin_id
  end

  # Mute handling
  def handle_mute_action(mute)
    if mute
      Mute.find_or_create_by!(
        account_id: admin_account_id,
        target_account_id: params[:account_id],
        hide_notifications: true
      )
    else
      Mute.find_by(account_id: admin_account_id, target_account_id: params[:account_id])&.destroy
    end
  end

  def unmute_target_account
    Mute.find_by(account_id: admin_account_id, target_account_id: params[:account_id])&.destroy
  end

  # Visibility handling
  def visibility_param
    params.dig(:community, :visibility).presence || 'public_access'
  end

  def handle_successful_visibility_update
    # admin_email = User.where(account_id: get_community_admin_id)
    # DashboardMailer.channel_created(@community, admin_email).deliver_now
    if @community.channel?
      CreateCommunityInstanceDataJob.perform_later(@community.id, @community.slug) if channels_allowed?
      redirect_to communities_path(channel_type: 'channel')
    else
      redirect_to communities_path(channel_type: 'channel_feed')
    end
  end

  def handle_failed_visibility_update
    render @community.channel? ? :step6 : :step4
  end

  def channels_allowed?
    ENV['ALLOW_CHANNELS_CREATION'] == 'true'
  end

  # Filter initializers
  def commu_records_filter
    Filter::Community.new(params, current_user)
  end

  def commu_admin_records_filter
    initialize_filter(Filter::CommunityAdmin, { patchwork_community_id_eq: @community.id })
  end

  def commu_hashtag_records_filter
    initialize_filter(Filter::CommunityHashtag, { patchwork_community_id_eq: @community.id })
  end

  def post_hashtag_records_filter
    initialize_filter(Filter::PostHashtag, { patchwork_community_id_eq: @community.id })
  end

  def initialize_filter(filter_class, query_params)
    params[:q] = query_params
    filter_class.new(params)
  end

  # Common methods
  def set_community
    @community = Community.find(params[:id])
    authorize @community, :initialize_form?
  rescue ActiveRecord::RecordNotFound
    not_found
  end

  def default_channel_type
    current_user.user_admin? ? 'channel_feed' : 'channel'
  end

  def set_current_step
    @current_step = action_name[/\d+/].to_i || 1
  end

  def new_community_post_type
    CommunityPostType.new(patchwork_community_id: @community.id)
  end

  def handle_update_error(redirect_path)
    flash[:error] = @community.errors.full_messages.join(", ")
    redirect_to redirect_path
  end

  # Bluesky integration
  def invoke_bridged
    @bluesky_info = BlueskyService.new(@community).fetch_bluesky_account
  end
end
