# frozen_string_literal: true

require 'httparty'
require 'nokogiri'

class AccountRelationshipsService < BaseService
  def call(admin_account, target_account_id)
    @admin_account = admin_account
    follow_bluesky_bot?(target_account_id)
  end

  private

  def follow_bluesky_bot?(target_account_id)
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    token = fetch_oauth_token
    return unless token

    response = check_account_relationship(target_account_id, api_base_url, token)

    if response.code == 200
      results = JSON.parse(response.body)
      results
    else
      Rails.logger.error("Failed to fetch relationships account_id #{@admin_account&.id} | target_account_id #{target_account_id}: #{response.body}")
      []
    end
  end

  def check_account_relationship(target_account_id, api_base_url, token)
    HTTParty.get("#{api_base_url}/api/v1/accounts/relationships",
                 query: { with_suspended: true, id: [target_account_id] },
                 headers: { 'Authorization' => "Bearer #{token}" })
  end

  def fetch_oauth_token
    return nil unless @admin_account&.user
    token_service = GenerateAdminAccessTokenService.new(@admin_account.user.id)
    token_service.call
  end

end
