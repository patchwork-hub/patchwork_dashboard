module ApplicationHelper
  def url_for_page(page)
    url_for(request.params.merge(page: page))
  end

  def sidebar_menu_items

    if user_admin?
      channel = "Channel feeds"
      icon = "channel-feed.svg"
    else
      channel = "Channels"
      icon = "speech.svg"
    end

    channel_active = params[:channel_type] == 'channel' || @community&.channel? ? 'communities' : nil
    channel_feed_active = params[:channel_type] == 'channel_feed' || @community&.channel_feed? ? 'communities' : nil

    if master_admin?
      [
        { path: '/homepage', id: 'homepage-link', header: 'Homepage', icon: 'home.svg', text: 'Home', active_if: 'homepage' },
        { path: server_settings_path, id: 'server-settings-link', header: 'Server settings', icon: 'sliders.svg', text: 'Server settings', active_if: ['server_settings', 'keyword_filter_groups', 'keyword_filters'] },
        { path: '/installation', id: 'installation-link', header: 'Installation', icon: 'screwdriver-wrench.svg', text: 'Installation', active_if: 'installation' },
        { path: communities_path(channel_type: 'channel'), id: 'communities-link', header: 'Channels', icon: 'speech.svg', text: 'Channels', active_if: channel_active  },
        { path: communities_path(channel_type: 'channel_feed'), id: 'communities-link', header: 'Channel feeds', icon: 'channel-feed.svg', text: 'Channel feeds', active_if: channel_feed_active },
        { path: collections_path, id: 'collections-link', header: 'Collections', icon: 'collection.svg', text: 'Collections', active_if: 'collections' },
        { path: master_admins_path, id: 'master_admins-link', header: 'Master Admin', icon: 'administrator.svg', text: 'Master admins', active_if: 'master_admins' },
        { path: accounts_path, id: 'accounts-link', header: 'Users', icon: 'users.svg', text: 'Users', active_if: 'accounts' },
        { path: resources_path, id: 'resources-link', header: 'Resources', icon: 'folder.svg', text: 'Resources', active_if: 'resources' },
        { path: api_keys_path, id: 'resources-link', header: 'API Key', icon: 'key.svg', text: 'API Key', active_if: 'api_keys' },
        { path: "/sidekiq", id: 'sidekiq-link', header: 'Sidekiq', icon: 'smile-1.svg', text: 'Sidekiq', target: '_blank' },
        { path: '#', id: 'help-support-link', header: 'Help & Support', icon: 'question.svg', text: 'Help & Support', active_if: 'help_support' }
      ]
    else
      [
        { path: communities_path, id: 'communities-link', header: channel, icon: icon, text: channel, active_if: 'communities' },
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

  def carousel_indicators(current_step, community)
    total_steps = @community&.channel_feed? ? 4 : 6
    content_tag(:ol, class: 'carousel-indicators') do
      (1..total_steps).map do |step|
        css_class = step <= current_step ? 'bg-danger active' : 'bg-secondary'
        content_tag(:li, '', class: css_class, style: 'width: 65px; height: 5px;')
      end.join.html_safe
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
end
