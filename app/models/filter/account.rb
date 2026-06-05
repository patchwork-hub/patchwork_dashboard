class Filter::Account < Filter::Common

  def initialize(params)
    @query = params[:q].to_s.strip
    @role_id_nil = params[:role_id_nil]
    @current_page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = DEFAULT_ITEMS_LIMIT
    @total_pages = (public_scope.count.to_f / @per_page).ceil
  end

  def paginated_scope
    public_scope.offset((@current_page - 1) * @per_page).limit(@per_page)
  end

  def build_search
    public_scope
  end

  def get
    paginated_scope
  end

  private

  def base_scope
    scope = Account.joins(:user)
                   .includes(:user)
                   .where.not(users: { confirmed_at: nil })

    scope = scope.where(users: { role_id: nil }) if @role_id_nil
    scope
  end

  def public_scope
    scope = base_scope

    return scope if @query.blank?

    if exact_username_domain_query?
      local_domain = ENV['LOCAL_DOMAIN'].presence || Rails.configuration.x.local_domain

      scope.where(
        "LOWER(accounts.username) = :username AND LOWER(COALESCE(accounts.domain, :local_domain)) = :domain",
        username: exact_username,
        local_domain: local_domain.to_s.downcase,
        domain: exact_domain
      )
    else
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

      scope.where(
        "accounts.username ILIKE :term OR accounts.display_name ILIKE :term OR users.email ILIKE :term",
        term: search_term
      )
    end
  end

  def exact_username_domain_query?
    @query.match?(/\A@([^@]+)@([^@]+)\z/)
  end

  def exact_username
    @query.match(/\A@([^@]+)@([^@]+)\z/)[1].downcase
  end

  def exact_domain
    @query.match(/\A@([^@]+)@([^@]+)\z/)[2].downcase
  end
end
