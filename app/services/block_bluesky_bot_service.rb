class BlockBlueskyBotService
  # Require AWS service for Route53 client
  require_relative 'aws_service'

  include ApplicationHelper

  def initialize
  end

  def call
    users = User.where.not(did_value: nil).where(bluesky_bridge_enabled: false)
    return unless users.any?

    users.each do |user|
      block_bluesky_bot(user)
    end
  end

  private

  def block_bluesky_bot(user)
    account = user&.account
    return if account.nil?

    token = fetch_oauth_token(user)
    return if token.nil?

    target_account_id = Rails.cache.fetch('bluesky_bridge_bot_account_id', expires_in: 24.hours) do
      search_target_account_id(token)
    end
    return if target_account_id.nil?

    block_account(token, target_account_id)

  end

  def fetch_oauth_token(user)
    GenerateAdminAccessTokenService.new(user&.id).call
  end

  def search_target_account_id(token)
    query = '@bsky.brid.gy@bsky.brid.gy'
    retries = 5
    result = nil

    while retries >= 0
      result = ContributorSearchService.new(query, url: ENV['MASTODON_INSTANCE_URL'], token: token).call
      if result.any?
        return result.last['id']
      end
      retries -= 1
    end
    nil
  end

  def block_account(token, target_account_id)
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    headers = { 'Authorization' => "Bearer #{token}" }

    HTTParty.post(
      "#{api_base_url}/api/v1/accounts/#{target_account_id}/block",
      headers: headers
    )
  end
end