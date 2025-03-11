module ApplicationHelper
  include BlueskyAccountBridgeHleper
  include CommunityHelper
  def url_for_page(page)
    url_for(request.params.merge(page: page))
  end

  def sidebar_menu_items
    channel_active = params[:channel_type] == 'channel' || @community&.channel? ? 'communities' : nil
    channel_feed_active = params[:channel_type] == 'channel_feed' || @community&.channel_feed? ? 'communities' : nil
    hub_active = params[:channel_type] == 'hub' || @community&.hub? ? 'communities' : nil

    if master_admin?
      [
        { path: '/homepage', id: 'homepage-link', header: 'Homepage', icon: 'home.svg', text: 'Home', active_if: 'homepage' },
        { path: server_settings_path, id: 'server-settings-link', header: 'Server settings', icon: 'sliders.svg', text: 'Server settings', active_if: ['server_settings', 'keyword_filter_groups', 'keyword_filters'] },
        { path: '/installation', id: 'installation-link', header: 'Installation', icon: 'screwdriver-wrench.svg', text: 'Installation', active_if: 'installation' },
        { path: communities_path(channel_type: 'channel'), id: 'communities-link', header: 'Communities', icon: 'speech.svg', text: 'Communities', active_if: channel_active },
        { path: communities_path(channel_type: 'channel_feed'), id: 'communities-link', header: 'Channels', icon: 'channel-feed.svg', text: 'Channels', active_if: channel_feed_active },
        { path: communities_path(channel_type: 'hub'), id: 'communities-link', header: 'Hubs', icon: 'hub.svg', text: 'Hubs', active_if: hub_active },
        { path: collections_path, id: 'collections-link', header: 'Collections', icon: 'collection.svg', text: 'Collections', active_if: 'collections' },
        { path: master_admins_path, id: 'master_admins-link', header: 'Master admin', icon: 'administrator.svg', text: 'Master admins', active_if: 'master_admins' },
        { path: accounts_path, id: 'accounts-link', header: 'Users', icon: 'users.svg', text: 'Users', active_if: 'accounts' },
        { path: resources_path, id: 'resources-link', header: 'Resources', icon: 'folder.svg', text: 'Resources', active_if: 'resources' },
        { path: api_keys_path, id: 'resources-link', header: 'API Key', icon: 'key.svg', text: 'API Key', active_if: 'api_keys' },
        { path: wait_lists_path, id: 'invitation-codes-link', header: 'Invitation codes', icon: 'invitation_code.svg', text: 'Invitation codes', active_if: 'wait_lists' },
        { path: "/sidekiq", id: 'sidekiq-link', header: 'Sidekiq', icon: 'smile-1.svg', text: 'Sidekiq', target: '_blank' },
        { path: '#', id: 'help-support-link', header: 'Help & Support', icon: 'question.svg', text: 'Help & Support', active_if: 'help_support' }
      ]
    elsif organisation_admin?
      [
        { path: communities_path(channel_type: 'channel'), id: 'communities-link', header: 'Communities', icon: 'speech.svg', text: 'Communities', active_if: channel_active },
        { path: '#', id: 'help-support-link', header: 'Help & Support', icon: 'question.svg', text: 'Help & Support', active_if: 'help_support' }
      ]
    elsif user_admin?
      [
        { path: communities_path(channel_type: 'channel_feed'), id: 'communities-link', header: 'Channels', icon: 'channel-feed.svg', text: 'Channels', active_if: channel_feed_active },
        { path: '#', id: 'help-support-link', header: 'Help & Support', icon: 'question.svg', text: 'Help & Support', active_if: 'help_support' }
      ]
    else
      [
        { path: communities_path(channel_type: 'hub'), id: 'communities-link', header: 'Hubs', icon: 'hub.svg', text: 'Hubs', active_if: hub_active },
        { path: '#', id: 'help-support-link', header: 'Help & Support', icon: 'question.svg', text: 'Help & Support', active_if: 'help_support' }
      ]
    end
  end

  def active_class(active_if)
    if active_if.is_a?(Array)
      active_if.include?(controller_name) ? 'active' : ''
    else
      controller_name == active_if ? 'active' : ''
    end
  end

  def get_my_server
    if master_admin?
      ENV.fetch('MASTODON_INSTANCE_URL', '#')
    else
      username = current_user&.account&.username
      username ? "https://#{username.dasherize}.channel.org" : '#'
    end
  end

  def master_admin?
    current_user && policy(current_user).master_admin?
  end

  def organisation_admin?
    current_user && policy(current_user).organisation_admin?
  end

  def user_admin?
    current_user && policy(current_user).user_admin?
  end

  def hub_admin?
    current_user && policy(current_user).hub_admin?
  end
end
