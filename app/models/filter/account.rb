class Filter::Account < Filter::Common

  def initialize(params)
    super(params)
  end

  def paginated_scope
    Account.includes(:user).where.not(user: {confirmed_at: nil}).offset((@current_page - 1) * @per_page).limit(@per_page)
  end

  def build_search
    Account.ransack(@q)
  end
end
