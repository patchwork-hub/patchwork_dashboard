class NonChannelBlueskyBridgeService
  include ApplicationHelper

  def initialize
  end

  def process_users
    users = User.where(did_value: nil, bluesky_bridge_enabled: true)
    return unless users.any?

    users.each do |user|
      process_user(user)
    end
  end

  private

  def process_user(user)
    use_local_domain = ActiveModel::Type::Boolean.new.cast(ENV.fetch('USE_LOCAL_DOMAIN', 'true'))
    account = user&.account
    return if account.nil?

    token = fetch_oauth_token(user)
    return if token.nil?

    target_account_id = Rails.cache.fetch('bluesky_bridge_bot_account_id', expires_in: 24.hours) do
      search_target_account_id(token)
    end
    target_account = Account.find_by(id: target_account_id)
    return if target_account.nil?

    # Check if user is blocked by the bridge bot
    blocked =  UserBlockedByBridgeBotService.new(user, token, target_account_id).call

    # If user is blocked, unblock the bluesky bridge bot account
    if blocked
      UnblockAccountService.new(token, target_account_id).call
    end

    account_relationship_array = handle_relationship(account, target_account.id)
    return unless account_relationship_array.present? && account_relationship_array&.last

    if account_relationship_array&.last['requested']
      UnfollowService.new.call(account, target_account)
    end

    return unless bluesky_bridge_enabled?(account)

    if account_relationship_array&.last['following'] == false
      FollowService.new.call(account, target_account)
      account_relationship_array = handle_relationship(account, target_account.id)
    end

    if use_local_domain
      process_did_value(user, token, account) if account_relationship_array.present? && account_relationship_array&.last && account_relationship_array&.last['following']
    else
      Rails.logger.info("Skipping DNS record creation for user #{user.account&.username} - using Bridgy Fed default handle")
    end
  end

  def bluesky_bridge_enabled?(account)
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
        return result.last['id']
      end
      retries -= 1
    end
    nil
  end

  def fetch_oauth_token(user)
    GenerateAdminAccessTokenService.new(user&.id).call
  end

  def process_did_value(user, token, account)
    did_value = FetchDidValueService.new.call(account, user)

    if did_value
      begin
        create_dns_record(did_value, account)
        sleep 1.minutes
        create_direct_message(token, account)
        user.update!(did_value: did_value)
      rescue StandardError => e
        Rails.logger.error("Error processing did_value for user #{account.username}: #{e.message}")
      end
    end
  end

  def create_dns_record(did_value, account)
    # Check if we should use local domain DNS or Bridgy Fed default
    use_local_domain = ActiveModel::Type::Boolean.new.cast(ENV.fetch('USE_LOCAL_DOMAIN', 'true'))
    
    # Skip DNS record creation if not using local domain (Bridgy Fed will handle it)
    unless use_local_domain
      Rails.logger.info("Skipping DNS record creation for user #{account&.username} - using Bridgy Fed default handle")
      return
    end

    # Determine the domain and record name for the user account
    base_domain = ENV['LOCAL_DOMAIN']
    record_name = "_atproto.#{account&.username}.#{ENV['LOCAL_DOMAIN']}"
    record_value = "did=#{did_value}"

    # Use DNS provider factory to create records across different providers
    dns_provider = DnsProviderFactory.create
    dns_provider.create_or_update_txt_record(base_domain, record_name, record_value)
  rescue StandardError => e
    Rails.logger.error("Failed to create DNS record for #{account&.username}: #{e.message}")
    raise e
  end

  def create_direct_message(token, account)

    name = "#{account&.username}@#{ENV['LOCAL_DOMAIN']}"

    status_params = {
      "in_reply_to_id": nil,
      "language": "en",
      "media_ids": [],
      "poll": nil,
      "sensitive": false,
      "spoiler_text": "",
      "status": "@bsky.brid.gy@bsky.brid.gy username #{name}",
      "visibility": "direct"
    }

    PostStatusService.new.call(token: token, options: status_params)
  end

  def handle_relationship(account, target_account_id)
    AccountRelationshipsService.new.call(account, target_account_id)
  end
end
