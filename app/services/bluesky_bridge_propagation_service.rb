class BlueskyBridgePropagationService
  def call(target_type, target_id, did_value)
    user, account, target = target_details(target_type, target_id)
    return unless user && account && target

    token = GenerateAdminAccessTokenService.new(user.id).call
    return unless token

    create_direct_message(token, account)
    persist_did_value(target, did_value)
  end

  private

  def target_details(target_type, target_id)
    case target_type
    when 'community'
      community = Community.find_by(id: target_id)
      return unless community

      community_admin = CommunityAdmin.find_by(
        patchwork_community_id: community.id,
        is_boost_bot: true
      )
      account = community_admin&.account
      user = User.find_by(email: community_admin&.email, account_id: account&.id)
      [user, account, community]
    when 'user'
      user = User.find_by(id: target_id)
      [user, user&.account, user]
    end
  end

  def create_direct_message(token, account)
    base_domain = ENV['LOCAL_DOMAIN'].split('.').last(2).join('.')
    name = "#{account.username}.#{base_domain}"

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

  def persist_did_value(target, did_value)
    if target.is_a?(User)
      target.update_column(:did_value, did_value)
    else
      target.update!(did_value: did_value)
    end
  end
end