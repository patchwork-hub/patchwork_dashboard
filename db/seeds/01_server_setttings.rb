if ServerSetting.count == 0

  settings = [
    {
      name: 'Spam Block',
      options: ['Spam filters', 'Sign up challenge']
    },
    {
      name: 'Content Moderation',
      options: ['Content filters']
    },
    {
      name: 'Federation',
      options: ['Bluesky', 'Threads', 'Live blocklist']
    },
    {
      name: 'Local Features',
      options: ['Custom theme', 'Automatic Search Opt-out', 'Local only posts', 'Long posts', 'Local quote posts']
    },
    {
      name: 'User Management',
      options: ['Guest accounts', 'e-Newsletters', 'Analytics']
    },
    {
      name: 'Plug-ins',
      options: []
    },
    {
      name: 'Bluesky Bridge',
      options: ['Automatic Bluesky bridging for new users']
    },
    {
      name: 'Email Branding',
      options: []
    }
  ]

  settings.each do |setting|
    server_setting = ServerSetting.create(name: setting[:name])

    setting[:options].each_with_index do |option, index|
      ServerSetting.create(name: option, position: (index + 1), parent_id: server_setting.id)
    end
  end

  p 'Server Settings are created!!'
end
