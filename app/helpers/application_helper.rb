module ApplicationHelper
  def url_for_page(page)
    url_for(request.params.merge(page: page))
  end

  def sidebar_menu_items
    [
      { path: '/homepage', id: 'homepage-link', header: 'Homepage', icon: 'home.svg', text: 'Home', active_if: 'homepage' },
      { path: server_settings_path, id: 'server-settings-link', header: 'Server settings', icon: 'sliders.svg', text: 'Server settings', active_if: ['server_settings', 'keyword_filter_groups', 'keyword_filters'] },
      { path: '/installation', id: 'installation-link', header: 'Installation', icon: 'screwdriver-wrench.svg', text: 'Installation', active_if: 'installation' },
      { path: '/patch_packs', id: 'patch-packs-link', header: 'Patch Packs', icon: 'boxes.svg', text: 'Patch Packs', active_if: 'patch_packs' },
      { path: communities_path, id: 'communities-link', header: 'Communities', icon: 'speech.svg', text: 'Communities', active_if: 'communities' },
      { path: accounts_path, id: 'accounts-link', header: 'Users', icon: 'users.svg', text: 'Users', active_if: 'accounts' },
      { path: resources_path, id: 'resources-link', header: 'Resources', icon: 'folder.svg', text: 'Resources', active_if: 'resources' },
      { path: api_keys_path, id: 'resources-link', header: 'API Key', icon: 'key.svg', text: 'API Key', active_if: 'api_keys' },
      { path: "/sidekiq", id: 'sidekiq-link', header: 'Sidekiq', icon: 'smile-1.svg', text: 'Sidekiq', target: '_blank' },
      { path: '#', id: 'help-support-link', header: 'Help & Support', icon: 'question.svg', text: 'Help & Support', active_if: 'help_support' }
    ]
  end

  def active_class(active_if)
    if active_if.is_a?(Array)
      active_if.include?(controller_name) ? 'active' : ''
    else
      controller_name == active_if ? 'active' : ''
    end
  end
end
