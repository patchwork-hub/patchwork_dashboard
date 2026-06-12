require 'httparty'

class RemoteAccountVerifyService
  VERIFY_CREDENTIALS_TIMEOUT_SECONDS = 3
  SEARCH_RETRY_ATTEMPTS = 3

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
      response = HTTParty.get(
        url,
        headers: { 'Authorization' => "Bearer #{@token}" },
        timeout: VERIFY_CREDENTIALS_TIMEOUT_SECONDS
      )
      @remote_account = JSON.parse(response.body)
    rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, JSON::ParserError => e
      Rails.logger.error "Error fetching #{@domain}'s account info: #{e.message}"
      nil
    end
  end

  def fetch_remote_account_id
    return nil unless @remote_account.is_a?(Hash) && @remote_account['username'].present?

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
    # Owner account's user id
    owner_user = User.find_by(role: UserRole.find_by(name: 'Owner'))
    return nil unless owner_user

    token = GenerateAdminAccessTokenService.new(owner_user.id).call
    return nil if token.blank?

    SEARCH_RETRY_ATTEMPTS.times do
      result = ContributorSearchService.new(query, url: ENV['MASTODON_INSTANCE_URL'], token: token).call
      return result.last['id'] if result.any?
    end

    nil
  end 
end
