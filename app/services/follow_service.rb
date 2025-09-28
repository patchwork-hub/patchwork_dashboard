class FollowService < BaseService
  def call(admin, target_account, reblogs: true)
    @admin = admin
    @target_account = target_account
    @reblogs = reblogs
    follow_contributor!
  end

  def follow_contributor!
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    token = fetch_oauth_token
    response = follow_account(api_base_url, token)
    account_data = process_api_response(response)
    find_account(account_data)
  rescue HTTParty::Error => e
    puts "HTTP request failed: #{e.message}"
  rescue StandardError => e
    puts "An unexpected error occurred: #{e.message}"
  end

  def follow_account(api_base_url, token)
    payload = {
      reblogs: @reblogs
    }

    headers = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }

    response = HTTParty.post("#{api_base_url}/api/v1/accounts/#{@target_account.id}/follow",
                             body: payload.to_json,
                             headers: headers)

    unless response.code == 200
      Rails.logger.error("Failed to follow account: #{response.body}")
    end

    response
  end

  def fetch_oauth_token
    return nil unless @admin.user
    token_service = GenerateAdminAccessTokenService.new(@admin.user.id)
    token_service.call
  end

  def process_api_response(response)
    sleep 2
    account_data = response.parsed_response
    return nil if account_data.nil?

    account_data
  end

  def find_account(account_data)
    Account.find_by(id: account_data['id'])
  end
end
