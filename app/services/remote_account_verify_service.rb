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
    # Find account in local server
    domain = @domain
    if @domain == 'backend.newsmast.org'
      domain = 'newsmast.social'
    end
    account_id = if acc = Account.find_by(username: @remote_account["username"], domain: domain)
      acc.id
    else
      account_handler = "@#{@remote_account["username"]}@#{domain}"
      search_target_account_id(account_handler)
    end
    account_id
  end

  def search_target_account_id(query)
    retries = 5
    result = nil
  
    # Owner account's user id
    owner_user = User.find_by(role: UserRole.find_by(name: 'Owner'))
    token = GenerateAdminAccessTokenService.new(owner_user.id).call

    while retries >= 0
      result = ContributorSearchService.new(query, url: ENV['MASTODON_INSTANCE_URL'], token: token).call
      if result.any?
        return result.last['id']
      end
      retries -= 1
    end
    nil
  end 
end
