require 'httparty'

class RemoteAccountVerifyService
  def initialize(token, domain)
    @token = token
    @domain = domain
    @remote_account = nil
  end

  def call
    verify_account_credentials
    self
  end

  def verify_account_credentials
    begin
      url = "https://#{@domain}/api/v1/accounts/verify_credentials"
      response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{@token}" })
      @remote_account = JSON.parse(response.body)
    rescue HTTParty::Error => e
      Rails.logger.error "Error fetching #{@domain}'s account info: #{e.message}"
      nil
    end
  end

  def fetch_remote_account_id
    username = @remote_account['username']
    account_domain = @domain == ENV.fetch('LOCAL_DOMAIN', nil) ? nil : @domain
    account_domain = 'newsmast.social' if @domain == 'backend.newsmast.org'

    account = Account.find_by(username: username, domain: account_domain)
    return account.id if account

    search_domain = account_domain || @domain
    search_target_account_id("@#{username}@#{search_domain}")
  end

  def search_target_account_id(query)
    retries = 5
    result = nil
    username, domain = query.delete_prefix('@').split('@')
    # Owner account's user id
    owner_user = User.find_by(role: UserRole.find_by(name: 'Owner'))
    token = GenerateAdminAccessTokenService.new(owner_user.id).call
 
    while retries >= 0
      result = ContributorSearchService.new(query, url: ENV['MASTODON_INSTANCE_URL'], token: token).call
      matched_accounts = result.select { |account| account['username'] == username && account['domain'] == domain }
      if matched_accounts.any?
        return matched_accounts.last['id']
      end
      retries -= 1
    end
    nil
  end
end
