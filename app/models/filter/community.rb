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
    # Omit the following line if you don't want to filter by channel_type
    exclude_community_types = CommunityType.where(slug: ['multi-platform', 'multi-contributor']).pluck(:id)
    scope = scope.where.not(patchwork_community_type_id: exclude_community_types) if exclude_community_types.present?
    scope.page(@current_page).per(@per_page)
  end

  def build_search
    if master_admin?
      Community.ransack(@q)
    else
      Community.joins(:community_admins)
               .where(community_admins: { account_id: account_id })
               .ransack(@q)
    end
  end

  def master_admin?
    @current_user&.role&.name.in?(%w[MasterAdmin])
  end

  def account_id
    @current_user.account_id
  end
end
