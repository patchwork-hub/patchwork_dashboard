class ContributorSearchService
  def initialize(query, options = {})
    @query = query
    @api_base_url = options[:url]
    @token = options[:token]
  end

  def call
    response = search_mastodon
    accounts = response.parsed_response['accounts']
    find_saved_accounts_with_retry(accounts)
  end

  private

  def search_mastodon
    HTTParty.get("#{@api_base_url}/api/v2/search",
      query: {
        q: @query,
        resolve: true,
        limit: 11
      },
      headers: {
        'Authorization' => "Bearer #{@token}"
      }
    )
  end

  def find_saved_accounts_with_retry(accounts)
    return [] unless accounts.present?

    saved_accounts = []
    while saved_accounts.empty?
      saved_accounts = Account.where(username: accounts.map { |account| account['username'] })
      sleep(2) if saved_accounts.empty?
    end

    saved_accounts.map do |account|
      {
        'id' => account.id.to_s,
        'username' => account.username,
        'display_name' => account.display_name,
        'domain' => account.domain,
        'note' => account.note
      }
    end
  end
end
