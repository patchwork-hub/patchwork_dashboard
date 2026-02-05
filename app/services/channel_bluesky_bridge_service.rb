class ChannelBlueskyBridgeService
  include ApplicationHelper

  def initialize
  end

  def process_communities
    communities = Community.where(did_value: nil).exclude_incomplete_channels.exclude_deleted_channels
    return unless communities.any?

    communities.each do |community|
      process_community(community)
    end
  end

  private

  def process_community(community)
    use_local_domain = ActiveModel::Type::Boolean.new.cast(ENV.fetch('USE_LOCAL_DOMAIN', 'true'))
    community_admin = CommunityAdmin.find_by(patchwork_community_id: community&.id, is_boost_bot: true)
    return if community_admin.nil?

    account = community_admin&.account
    return if account.nil?

    user = User.find_by(email: community_admin&.email, account_id: account&.id)
    return if user.nil?

    token = fetch_oauth_token(user)
    return if token.nil?

    target_account_id = Rails.cache.fetch('bluesky_bridge_bot_account_id', expires_in: 24.hours) do
      search_target_account_id(token)
    end
    target_account = Account.find_by(id: target_account_id)
    return if target_account.nil?

    account_relationship_array = handle_relationship(account, target_account.id)
    return unless account_relationship_array.present? && account_relationship_array&.last

    if account_relationship_array&.last['requested']
      UnfollowService.new.call(account, target_account)
    end

    return unless enable_bridge_bluesky?(account)

    if account_relationship_array&.last['following'] == false
      FollowService.new.call(account, target_account)
      account_relationship_array = handle_relationship(account, target_account.id)
    end

    if use_local_domain
      process_did_value(community, token, account) if account_relationship_array.present? && account_relationship_array&.last && account_relationship_array&.last['following']
    else
      Rails.logger.info("Skipping DNS record creation for community #{community.name} - using Bridgy Fed default handle")
    end
  end

  def enable_bridge_bluesky?(account)
    account&.username.present? && account&.display_name.present? &&
    account&.avatar.present? && account&.header.present?
  end

  def search_target_account_id(token)
    query = '@bsky.brid.gy@bsky.brid.gy'
    retries = 5
    result = nil

    while retries >= 0
      result = ContributorSearchService.new(query, url: ENV['MASTODON_INSTANCE_URL'], token: token).call
      if result.any?
        target_account = result.find { |account| account['username'] == 'bsky.brid.gy' && account['domain'] == 'bsky.brid.gy' }
        return target_account['id'] if target_account
      end
      retries -= 1
    end
    nil
  end

  def fetch_oauth_token(user)
    GenerateAdminAccessTokenService.new(user&.id).call
  end

  def process_did_value(community, token, account)
    did_value = FetchDidValueService.new.call(account, community)

    if did_value
      begin
        create_dns_record(did_value, community)
        sleep 1.minutes
        create_direct_message(token, community)
        community.update!(did_value: did_value)
      rescue StandardError => e
        Rails.logger.error("Error processing did_value for community #{community.id}: #{e.message}")
      end
    end
  end

  def create_dns_record(did_value, community)
    did_value = FetchDidValueService.new.call(account, community)
    return unless did_value

    # Determine the domain and record name based on community configuration
    domain_name = determine_domain_name(community)
    base_domain = community&.is_custom_domain? ? community.slug : ENV['LOCAL_DOMAIN']
    record_name = "_atproto.#{domain_name}"
    record_value = "did=#{did_value}"

    # Use DNS provider factory to create records across different providers
    dns_provider = DnsProviderFactory.create
    dns_provider.create_or_update_txt_record(base_domain, record_name, record_value)
  rescue StandardError => e
    Rails.logger.error("Failed to create DNS record for #{domain_name}: #{e.message}")
    raise e
  end

  def create_direct_message(token, community)
    domain_name = determine_domain_name(community)

    status_params = {
      "in_reply_to_id": nil,
      "language": "en",
      "media_ids": [],
      "poll": nil,
      "sensitive": false,
      "spoiler_text": "",
      "status": "@bsky.brid.gy@bsky.brid.gy username #{domain_name}",
      "visibility": "direct"
    }

    PostStatusService.new.call(token: token, options: status_params)
  end

  def handle_relationship(account, target_account_id)
    AccountRelationshipsService.new.call(account, target_account_id)
  end

  def determine_domain_name(community)
    if community&.is_custom_domain?
      community&.slug
    else
      "#{community&.slug}.#{ENV['LOCAL_DOMAIN']}"
    end
  end
end
