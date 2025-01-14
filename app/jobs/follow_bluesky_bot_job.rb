# frozen_string_literal: true

class FollowBlueskyBotJob < ApplicationJob
  queue_as :default

  def perform(community_id)
    return if community_id.nil?
    puts "[FollowBlueskyBotJob] community_id: #{community_id}"

    community = Community.find_by(id: community_id)
    return if community.nil?
    puts "[FollowBlueskyBotJob] community: #{community}"

    community_admin = CommunityAdmin.find_by(patchwork_community_id: community&.id, is_boost_bot: true)
    return if community_admin.nil?
    puts "[FollowBlueskyBotJob] community_admin: #{community_admin}"

    user = User.find_by(email: community_admin&.email, account_id: community_admin&.account_id)
    return if user.nil?
    puts "[FollowBlueskyBotJob] user: #{user}"

    # Generate access token for community bot account
    @token = fetch_oauth_token(user)
    return if @token.nil?
    puts "[FollowBlueskyBotJob] @token: #{@token}"


    # Search for the bluesky bot account
    target_account = search_target_account
    return if target_account.nil?

    puts "[FollowBlueskyBotJob] target_account: #{target_account}"
    # Follow the bluesky bot account
    FollowService.new.call(community_admin&.account, target_account)
  end

  private

  def search_target_account
    query = '@bsky.brid.gy@bsky.brid.gy'

    result = SearchAccountService.new(query, url: ENV['MASTODON_INSTANCE_URL'], token: @token).call

    if result.any?
      Rails.logger.info("[FollowBlueskyBotJob - search_target_account] Found the bluesky bot account. #{result}")
      return Account.find_by(id: result.last['id'])
    else
      Rails.logger.error("[FollowBlueskyBotJob - search_target_account] Failed to find the bluesky bot account.")
      nil
    end
  end

  def fetch_oauth_token(user)
    token_service = GenerateAdminAccessTokenService.new(user&.id)
    token_service.call
  end

end