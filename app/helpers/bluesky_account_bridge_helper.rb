module BlueskyAccountBridgeHelper

  def check_account_info(community)
    error_messages = []
    error_message = nil
    account = community&.community_admins&.first&.account
    
    if account&.username.blank?
      error_messages << "username"
    end

    if account&.display_name.blank?
      error_messages << "display name"
    end

    if account&.avatar.blank?
      error_messages << "avatar"
    end

    if account&.header.blank?
      error_messages << "header"
    end

    if error_messages.any?
      error_message = "Your account is missing #{error_messages.join(', ')}."
    end
    
    error_message
  end

  def bridged_completely?(community, bridge_info)
    return false if community.nil? || !bridge_info.present?

    bridge_info['did'] == community.did_value && bridged_domain?(community, bridge_info)
  end

  def bridged_account_url(community, bridge_info)
    return false if community.nil? || !bridge_info.present?

    "https://bsky.app/profile/#{bridge_info['handle']}"
  end

  def bridged_handle(community, bridge_info)
    return false if community.nil? || !bridge_info.present?

    "@#{bridge_info['handle']}"
  end

  private

  def bridged_domain?(community, bridge_info)
    return false unless community && bridge_info&.key?('handle')

    handle = bridge_info['handle'].to_s.downcase

    # Avoid querying admins or account if not needed
    community_handle = if community.is_custom_domain?
                        community.slug.to_s
                      else
                        "#{community.slug}.channel.org"
                      end

    return true if handle == community_handle.to_s.downcase

    # Only fetch admin_account and account if first check fails
    admin_account = community&.community_admins.where(is_boost_bot: true).last
    return false unless admin_account

    account = Account.find_by(id: admin_account.account_id)
    return false unless account

    handle == account.username.to_s.downcase
  end

end
