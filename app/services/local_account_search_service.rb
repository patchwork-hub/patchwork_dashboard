class LocalAccountSearchService
  HANDLE_PATTERN = /\A@?(?<username>[A-Za-z0-9_]+)(?:@(?<domain>[A-Za-z0-9.-]+))?\z/

  def initialize(query)
    @query = query.to_s.strip
  end

  def call
    return Account.none if @query.blank?
    return Account.none if handle_domain.present? && !local_domain?(handle_domain)

    scope = Account.where(domain: nil)
    if exact_username_search?
      scope.where('LOWER(username) = :username', username: handle_username)
    else
      term = "%#{Account.sanitize_sql_like(search_term)}%"
      scope.where('username ILIKE :q OR display_name ILIKE :q', q: term)
    end.limit(20)
  end

  def self.local_domain
    ENV['LOCAL_DOMAIN'].presence ||
      ENV['WEB_DOMAIN'].presence ||
      begin
        URI.parse(ENV.fetch('MASTODON_INSTANCE_URL', '')).host
      rescue URI::InvalidURIError
        nil
      end
  end

  private

  def exact_username_search?
    handle_username.present? && (handle_domain.present? || @query.start_with?('@'))
  end

  def handle_username
    handle_match&.[](:username)&.downcase
  end

  def handle_domain
    handle_match&.[](:domain)&.downcase
  end

  def handle_match
    return @handle_match if defined?(@handle_match)

    @handle_match = HANDLE_PATTERN.match(@query)
  end

  def search_term
    handle_username.presence || @query.delete_prefix('@')
  end

  def local_domain?(domain)
    domains = known_local_domains
    return true if domains.empty?

    domains.include?(domain)
  end

  def known_local_domains
    [
      ENV['LOCAL_DOMAIN'],
      ENV['WEB_DOMAIN'],
      self.class.local_domain
    ].map { |value| value.to_s.strip.downcase.presence }.compact.uniq
  end
end
