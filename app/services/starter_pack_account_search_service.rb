class StarterPackAccountSearchService
  class SearchError < StandardError; end

  def initialize(query, user:)
    @query = query.to_s.strip
    @user = user
  end

  def call
    return [] if @query.blank?

    token = GenerateAdminAccessTokenService.new(@user.id).call
    raise SearchError if token.blank?

    response = HTTParty.get("#{ENV.fetch('MASTODON_INSTANCE_URL').chomp('/')}/api/v2/search",
      query: { q: @query, type: 'accounts', resolve: true, limit: 20 },
      headers: { 'Authorization' => "Bearer #{token}" }, timeout: 60)
    raise SearchError unless response.success?

    rows = response.parsed_response.fetch('accounts')
    raise SearchError unless rows.is_a?(Array)

    ids = rows.map { |row| row.fetch('id').to_s }
    saved_accounts = {}
    3.times do |attempt|
      saved_accounts = Account.where(id: ids).index_by { |account| account.id.to_s }
      break if (ids - saved_accounts.keys).empty?
      sleep(1) if attempt < 2
    end

    rows.filter_map do |row|
      account = saved_accounts[row.fetch('id').to_s]
      next unless account

      { id: account.id.to_s, username: account.username, acct: row['acct'],
        display_name: account.display_name, domain: account.domain,
        avatar_url: account.avatar_url, profile_url: row['url'] }
    end
  rescue SearchError
    raise
  rescue StandardError
    raise SearchError
  end
end