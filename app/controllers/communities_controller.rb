class CommunitiesController < BaseController
  before_action :authenticate_user!
  before_action :set_community, except: %i[step0 step0_save step1 step1_save index new]
  before_action :initialize_form, only: %i[step0 step1]
  before_action :set_current_step
  before_action :set_content_type, only: %i[step3 step4 step5 step6]
  before_action :set_api_credentials, only: %i[search_contributor step3 step4]
  before_action :fetch_community_admins, only: %i[step4 step6]
  before_action :initial_content_type, only: %i[index step0]

  include CommunityHelper

  PER_PAGE = 10
  COMMUNITY_FILTER_TYPES = { in: 'filter_in', out: 'filter_out' }.freeze

  # Main actions
  def index
    params[:channel_type] ||= params[:q]&.delete(:channel_type)
    redirect_to communities_path(request.query_parameters.merge(channel_type: default_channel_type)) unless params[:channel_type].present?
    @channel_type = params[:channel_type] || default_channel_type
    @search = commu_records_filter.build_search
    params[:status] ||= 'active'
    @records = load_filtered_records(commu_records_filter)
              .where(channel_type: @channel_type).includes([:content_type])
              .yield_self { |scope| apply_status_filter(scope, params[:status]) }
  end

  def upgrade
    community = Community.find(params[:id])

    if community.visibility.nil?
      flash[:error] = "Cannot upgrade incomplete channel!"
      redirect_back fallback_location: communities_path
      return
    end

    community.update!(channel_type: :channel, visibility: nil)

    if (admin = community.community_admins.first)
      admin.update!(role: "OrganisationAdmin")

      if (account = Account.find_by(id: admin.account_id))
        user_role = UserRole.find_by(name: "OrganisationAdmin")
        account.user.update!(role_id: user_role.id) if user_role
      end
    end

    redirect_to modify_community_path('channel', community)
  end

  def destroy
    @channel = Community.find(params[:id])
    @channel.soft_delete!
    Rails.logger.info "#{'*'*10} Destroy: deleted_at=> #{@channel.deleted_at} #{'*'*10}"
    Rails.logger.info "#{'*'*10} Destroy: admin=> #{@channel.community_admins.first} #{'*'*10}"
    if @channel.community_admins.first
      @channel.community_admins.first.update(account_status: :suspended)
    end
    redirect_to communities_path(channel_type: params[:channel_type_param])
  end

  def recover
    @channel = Community.deleted.find(params[:id])
    channel_type = params[:channel_type_param]
    if @channel.recoverable?
      @channel.recover!
      if @channel.community_admins.first
        @channel.community_admins.first.update(account_status: :active)
      end
      redirect_to communities_path(channel_type: channel_type)
    else
      redirect_to communities_path(channel_type: channel_type)
    end
  end

  def step0
    authorize_step(:step0?)
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
    content_type =
      if current_user.user_admin? || @channel_type == "channel_feed" || current_user.newsmast_admin? || @channel_type == "newsmast"
        "custom_channel"
      elsif @channel_type == "hub"
        "broadcast_channel"
      else
        params[:content_type] || @community&.content_type
      end

    @community = CommunityPostService.new.call(
      current_user,
      form_params.merge(
        community_type_id: CommunityType.first&.id,
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
    invoke_bridged unless @community.hub? || Rails.env.development?
  end

  def step3
    authorize_step(:step3?)
    @records = load_filtered_records(commu_hashtag_records_filter)
    @search = commu_hashtag_records_filter.build_search
    @community_hashtag_form = Form::CommunityHashtag.new(community_id: @community.id)
    @follow_records = load_follow_records
    setup_filter_keywords(COMMUNITY_FILTER_TYPES[:in])
  end

  def step4
    authorize_step(:step4?)
    verify_hashtags_presence if params[:action] == 'step4' && params[:page].blank?
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

  def follower_list
    @records = load_follower_records(is_csv: false).page(params[:page]).per(PER_PAGE)
  end

  def follower_list_csv
    @records = load_follower_records(is_csv: true)

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Display Name", "Username", "Email"]
      @records.each do |account|
        csv << [
          account&.display_name.present? ? account&.display_name : " - " ,
          "@#{username(account)}@#{domain(account)}",
          account&.user&.email || " - "
        ]
      end
    end

    respond_to do |format|
      format.csv { send_data csv_data, filename: "#{@community&.slug}_followers_list_#{@community.id}.csv" }
    end
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
          is_recommended: @community.is_recommended,
          no_boost_channel: @community.no_boost_channel,
          is_custom_domain: @community.is_custom_domain,
          ip_address_id: @community.ip_address_id
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
    @community_admins = CommunityAdmin.where(patchwork_community_id: @community.id, account_status: 0)
  end

  # Parameter handling
  def form_params
    params.require(:form_community).permit(
      :id, :name, :slug, :collection_id, :bio,
      :banner_image, :avatar_image, :logo_image,
      :community_type_id, :is_recommended, :no_boost_channel,
      :content_type, :channel_type, :is_custom_domain, :ip_address_id
    )
  end

  def prepare_for_step6_rendering
    fetch_community_admins
    CommunityLink.build if @community.patchwork_community_rules.empty?
    @community.patchwork_community_additional_informations.build if @community.patchwork_community_additional_informations.empty?
    @community.social_links.build if @community.social_links.empty?
    @community.general_links.build if @community.general_links.empty?
  end

  def community_params
    params.require(:community).permit(
      :post_visibility,
      patchwork_community_additional_informations_attributes: [:id, :heading, :text, :_destroy],
      social_links_attributes: [:id, :icon, :name, :url, :_destroy],
      general_links_attributes: [:id, :icon, :name, :url, :_destroy],
      patchwork_community_rules_attributes: [:id, :rule, :_destroy],
      registration_mode: []
    )
  end

  # Action handlers
  def handle_step1_error(content_type, channel_type)
    @community_form = Form::Community.new(
      form_params.merge(
        content_type: content_type,
        channel_type: channel_type,
        id: params[:id] || @community.id
      )
    )
    flash.now[:error] = @community.formatted_error_messages.join(', ')
    render :step1, status: :unprocessable_entity
  end

  def redirect_after_step1_save
    path = path = (current_user.master_admin? || current_user.user_admin? || current_user.hub_admin? || current_user.newsmast_admin?) ? :step2 : (params[:content_type] == 'custom_channel' ? :step3 : :step6)
    redirect_to send("#{path}_community_path", @community, channel_type: @channel_type)
  end

  def update_additional_information
    @community.assign_attributes(community_params)
    @community.registration_mode = params[:registration_mode]

    if params[:community].blank?
      @community.errors.add(:base, "Missing additional information")
      prepare_for_step6_rendering
      render :step6
      return
    end

    begin
      if @community.save
        redirect_to step6_community_path(@community, show_preview: true)
      else
        flash.now[:error] = @community.formatted_error_messages.join(', ')
        prepare_for_step6_rendering
        render :step6
      end
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.error "#{'*'*10}Duplicate link URL for community #{@community.id} #{'*'*10}"
      @community.errors.add(:base, "Duplicate link URL for this community is not allowed.")
      prepare_for_step6_rendering
      flash.now[:error] = @community.formatted_error_messages.join(', ')
      render :step6
      return
    end
  end

  # Filter and load methods
  def load_filtered_records(filter)
    filter.get
  end

  def load_follow_records
    account_ids = Follow.where(account_id: admin_account_id).pluck(:target_account_id) +
                  FollowRequest.where(account_id: admin_account_id).pluck(:target_account_id)
    accounts = Account.where(id: account_ids)
    @follow_records_size = accounts.reject { |r| r.username == 'bsky.brid.gy' }.size
    paginated_records(accounts)
  end

  def load_follower_records(is_csv: false)
    account_ids = Follow.where(target_account_id: admin_account_id).pluck(:account_id)
    return Account.where(id: account_ids) if is_csv

    paginated_records(Account.where(id: account_ids))
  end

  def load_muted_accounts
    muted_ids = Mute.where(account_id: admin_account_id).pluck(:target_account_id)
    @muted_accounts_size = muted_ids.size
    paginated_records(Account.where(id: muted_ids))
  end

  # Authorization and verification
  def authorize_step(policy_method)
    community = @community || Community.new
    authorize community, policy_method
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
    if @community.channel? || @community.hub?
      CreateCommunityInstanceDataJob.perform_later(@community) if channels_allowed?

      channel_type = if @community.channel?
                       'channel'
                     elsif @community.hub?
                       'hub'
                     end

      redirect_to communities_path(channel_type: channel_type)
    elsif @community.channel_feed?
      redirect_to communities_path(channel_type: 'channel_feed')
    elsif @community.newsmast?
      redirect_to communities_path(channel_type: 'newsmast')
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

  def apply_status_filter(scope, status)
    case status
    when 'deleted'
      scope.where.not(deleted_at: nil)
    when 'active'
      scope.where(deleted_at: nil)
    else
      scope # all
    end
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
    if current_user.user_admin?
      'channel_feed'
    elsif current_user.hub_admin?
      'hub'
    elsif current_user.organisation_admin?
      'channel'
    else
      'newsmast'
    end
  end

  def set_current_step
    @current_step = action_name[/\d+/].to_i || 1
  end

  def new_community_post_type
    CommunityPostType.new(patchwork_community_id: @community.id)
  end

  # Bluesky integration
  def invoke_bridged
    @bluesky_info = BlueskyService.new(@community).fetch_bluesky_account
  end
end
