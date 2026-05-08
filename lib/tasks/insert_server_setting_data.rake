namespace :db do
  desc "Seed parent and child settings data"
  task insert_server_setting_data: :environment do

    # if ServerSetting.all.count > 0
    #   ServerSetting.destroy_all
    # end

    # if KeywordFilter.all.count > 0
    #   KeywordFilter.destroy_all
    # end
    puts "Inserting server settings & keywords..."

    # Sample data for parent settings
    parent_settings_data = {
      "spam_block"         => [],
      "content_moderation" => [],
      "federation"         => [],
      "local_features"     => [],
      "user_management"    => [],
      "plugins"            => [],
      "bluesky_bridge"     => [],
      "email_branding"     => []
    }

    # Create parent settings and set positions
    parent_settings_data.each_with_index do |(parent_key, _), index|
      parent_config = ServerSetting.config[parent_key]
      parent_name = parent_config&.fetch("name", parent_key.humanize) || parent_key.humanize

      # Skip if parent setting already exists
      existing_parent = ServerSetting.find_by(key: parent_key, parent_id: nil)
      existing_parent ||= ServerSetting.find_by(name: parent_name, parent_id: nil)
      if existing_parent
        puts "Skipping existing parent setting: #{parent_name}"
        next
      end

      parent_setting = ServerSetting.create!(name: parent_name, key: parent_key, value: nil)

      # Sample data for child settings with parent associations
      child_settings_data = {
        "spam_block" => [
          { key: "spam_filters",      value: false },
          { key: "signup_challenge",  value: false }
        ],
        "content_moderation" => [
          { key: "content_filters",   value: false }
        ],
        "federation" => [
          { key: "bluesky",           value: false },
          { key: "threads",           value: false },
          { key: "live_blocklist",    value: false }
        ],
        "local_features" => [
          { key: "custom_theme",      value: false },
          { key: "search_opt_out",    value: false },
          { key: "local_only_posts",  value: false },
          { key: "long_posts",        value: false },
          { key: "local_quote_posts", value: false },
        ],
        "user_management" => [
          { key: "guest_accounts",    value: false },
          { key: "newsletters",       value: false },
          { key: "analytics",         value: false }
        ],
        "plugins" => [

        ],
        "bluesky_bridge" => [
          { key: "bluesky_bridge_auto", value: false }
        ],
        "email_branding" => [

        ]
      }

      child_settings_data[parent_key].each_with_index do |child, child_index|
        child_config = ServerSetting.config[child[:key]]
        child_name = child_config&.fetch("name", child[:key].humanize) || child[:key].humanize

        # Skip if child setting already exists
        existing_child = ServerSetting.find_by(key: child[:key], parent_id: parent_setting.id)
        existing_child ||= ServerSetting.find_by(name: child_name, parent_id: parent_setting.id)
        if existing_child
          puts "Skipping existing child setting: #{child_name}"
          next
        end

        ServerSetting.create!(name: child_name, key: child[:key], value: child[:value], position: child_index + 1, parent_id: parent_setting.id)
      end
    end
    puts "Done insertion of server settings & keywords"
  end
end
