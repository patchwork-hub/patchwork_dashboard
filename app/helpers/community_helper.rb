module CommunityHelper
  def domain(account)
    return nil unless account&.present?

    if account&.domain?
      account&.domain
    else
      default_domain
    end
  end

  def username(account)
    return nil unless account&.present?

    account&.username
  end

  def account_url(account)
    return nil unless account&.present?

    protocol = %w[production staging].include?(ENV.fetch('RAILS_ENV', nil)) ? 'https' : 'http'
    "#{protocol}://#{domain(account)}/@#{username(account)}@#{domain(account)}"
  end

  def create_community_path(channel_type_param)
    if channel_type_param == 'channel'
      step0_new_communities_path(channel_type: channel_type_param)
    else
      step1_new_communities_path(channel_type: channel_type_param)
    end
  end

  def determine_channel_keyword(channel_type_param)
    case channel_type_param
    when 'hub'
      'hub'
    when 'channel'
      'community'
    else
      'channel'
    end
  end

  def edit_community_path(channel_type_param, community)
    if channel_type_param == 'channel'
      step0_communities_path(id: community.id, channel_type: channel_type_param)
    else
      step1_communities_path(id: community.id, channel_type: channel_type_param)
    end
  end

  def get_channel_content_type(community)
    content_type = @initial_content_types.find { |content_type| content_type[:value] == community&.content_type&.channel_type }
    channel_content_type = content_type[:name] if content_type.present?
  end

  def continue_path_for_step2(community)
    if community&.content_type&.custom_channel?
      step3_community_path(id: community.id, channel_type: community.channel_type)
    else
      step6_community_path(id: community.id, channel_type: community.channel_type)
    end
  end

  def continue_button_class(records)
    records.size.zero? ? 'disabled' : ''
  end

  def previous_path_for_step1(community, params)
    if organisation_admin? || params[:channel_type] == 'channel' || community&.channel?
      step0_communities_path(
        channel_type: params[:channel_type],
        content_type: params[:content_type],
        id: params[:id]
      )
    else
      communities_path(channel_type: community&.channel_type)
    end
  end

  def previous_path_for_step3(community)
    if current_user.organisation_admin?
      step1_communities_path(id: community.id, channel_type: community.channel_type)
    else
      step2_community_path(channel_type: community.channel_type)
    end
  end

  def continue_path_for_step3(community, content_type)
    if content_type&.custom_channel?
      step4_community_path(id: community.id, channel_type: community.channel_type)
    else
      step6_community_path(id: community.id, channel_type: community.channel_type)
    end
  end

  def previous_path_for_step6(community)
    return step4_community_path(id: community.id, channel_type: community.channel_type) if community&.content_type&.custom_channel?

    if organisation_admin?
      step1_communities_path(id: community.id, channel_type: community.channel_type, content_type: community&.content_type&.custom_channel?)
    elsif master_admin?
      step2_community_path(id: community.id, channel_type: community.channel_type)
    else
      step4_community_path(id: community.id, channel_type: community.channel_type)
    end
  end

  def channel_title(channel_type_param)
    case channel_type_param
    when 'hub'
      'Hubs'
    when 'channel'
      'Communities'
    when 'channel_feed'
      'Channels'
    else
      'Newsmast channels'
    end
  end

  def registration_mode_label(community)
    if community.channel?
      "Access settings"
    elsif community.hub?
      "Hub users"
    end
  end

  def hide_add_button
    !(params[:channel_type] == 'hub' && hub_admin?) &&
    !(params[:channel_type] == 'channel_feed' && user_admin?) &&
    !(params[:channel_type] == 'newsmast' && newsmast_admin?) &&
    !(params[:channel_type] == 'channel' && organisation_admin?)
  end

  def address_url(community)
    return nil unless valid_address?(community)

    protocol = %w[production staging].include?(ENV.fetch('RAILS_ENV', nil)) ? 'https' : 'http'
    if community&.is_custom_domain
      "#{protocol}://#{community&.slug}/public"
    else
      "#{protocol}://#{community&.slug}.#{default_domain}/public"
    end
  end

  private

  def default_domain
    ENV.fetch('LOCAL_DOMAIN', nil)
  end

  def valid_address?(community)

    return false unless community&.slug && community&.visibility && community&.channel_type.present?
    return false unless community&.channel? || community&.hub?

    %w[production staging].include?(ENV.fetch('RAILS_ENV', nil))
  end
end
