class Filter::Community < Filter::Common
  def initialize(params, current_user)
    @current_user = current_user
    super(params)
    @q = params[:q] || {}
    @channel_type = params[:channel_type]
    @current_page = params[:page] || 1
    @per_page = 10
  end

  def get
    scope = build_search.result.order(id: :desc)
    scope = scope.where(channel_type: @channel_type) if @channel_type.present?
    scope.page(@current_page).per(@per_page)
  end

  def build_search
    base_scope = if master_admin?
                   Community.all
                 else
                   Community.joins(:community_admins)
                            .where(community_admins: { account_id: account_id })

                 end

    base_scope.ransack(@q)
  end

  def master_admin?
    @current_user&.master_admin? ||
      @current_user&.can?(:manage_channels, :manage_channel_feeds, :manage_hubs, :manage_newsmast_channels)
  end

  def account_id
    @current_user.account_id
  end
end
