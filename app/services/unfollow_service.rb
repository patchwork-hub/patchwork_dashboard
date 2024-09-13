# frozen_string_literal: true

class UnfollowService < BaseService
  def call(admin, target_account)
    @admin = admin
    @target_account = target_account
    follow_contributor!
  end

  def follow_contributor!
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    token = fetch_oauth_token

    response = unfollow_account(api_base_url, token)
    account_data = process_api_response(response)
    account = find_account(account_data)

  rescue HTTParty::Error => e
    puts "HTTP request failed: #{e.message}"
  rescue StandardError => e
    puts "An unexpected error occurred: #{e.message}"
  end

  def unfollow_account(api_base_url, token)
    payload = { reblogs: true }
    headers = { 'Authorization' => "Bearer #{token}" }

    HTTParty.post("#{api_base_url}/api/v1/accounts/#{@target_account.id}/unfollow",
      body: payload,
      headers: headers
    )
  end

  def fetch_oauth_token
    return nil unless @admin.user
    Doorkeeper::AccessToken.find_by(resource_owner_id: @admin.user.id)&.token
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
