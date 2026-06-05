class Filter::Account < Filter::Common

  def initialize(params)
    super(params)
    @role_id_nil = params[:role_id_nil]
  end

  def paginated_scope
    public_scope.offset((@current_page - 1) * @per_page).limit(@per_page)
  end

  def build_search
    base_scope.ransack(@q)
  end

  private

  def base_scope
    scope = Account.joins(:user)
                   .includes(:user)
                   .where.not(users: { confirmed_at: nil })

    scope = scope.where(users: { role_id: nil }) if @role_id_nil
    scope
  end
end
