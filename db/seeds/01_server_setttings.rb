if ServerSetting.count == 0

  settings = [
    {
      key: 'spam_block',
      options: [
        { key: 'spam_filters' },
        { key: 'signup_challenge' }
      ]
    },
    {
      key: 'content_moderation',
      options: [
        { key: 'content_filters' }
      ]
    },
    {
      key: 'federation',
      options: [
        { key: 'bluesky' },
        { key: 'threads' },
        { key: 'live_blocklist' }
      ]
    },
    {
      key: 'local_features',
      options: [
        { key: 'custom_theme' },
        { key: 'search_opt_out' },
        { key: 'local_only_posts' },
        { key: 'long_posts' },
        { key: 'local_quote_posts' }
      ]
    },
    {
      key: 'user_management',
      options: [
        { key: 'guest_accounts' },
        { key: 'newsletters' },
        { key: 'analytics' }
      ]
    },
    {
      key: 'plugins',
      options: []
    },
    {
      key: 'bluesky_bridge',
      options: [
        { key: 'bluesky_bridge_auto' }
      ]
    },
    {
      key: 'email_branding',
      options: []
    }
  ]

  settings.each do |setting|
    config = ServerSetting.config[setting[:key]]
    server_setting = ServerSetting.create(
      name: config['name'],
      key: setting[:key]
    )

    setting[:options].each_with_index do |option, index|
      option_config = ServerSetting.config[option[:key]]
      ServerSetting.create(
        name: option_config['name'],
        key: option[:key],
        position: (index + 1),
        parent_id: server_setting.id
      )
    end
  end

  p 'Server Settings are created!!'
end
