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
      "Spam Block" => [],
      "Content Moderation" => [],
      "Federation" => [],
      "Local Features" => [],
      "User Management" => [],
      "Plug-ins" => [],
      "Bluesky Bridge" => []
    }

    # Create parent settings and set positions
    parent_settings_data.each_with_index do |(parent_name, _), index|
      # Skip if parent setting already exists
      existing_parent = ServerSetting.find_by(name: parent_name, parent_id: nil)
      if existing_parent
        puts "Skipping existing parent setting: #{parent_name}"
        next
      end
      
      parent_setting = ServerSetting.create!(name: parent_name, value: nil)

      # Sample data for child settings with parent associations
      child_settings_data = {
        "Spam Block" => [
          { name: "Spam filters", value: false },
          { name: "Sign up challenge", value: false }
        ],
        "Content Moderation" => [
          { name: "Content filters", value: false }
        ],
        "Federation" => [
          { name: "Bluesky", value: false },
          { name: "Threads", value: false },
          { name: "Live blocklist", value: false }
        ],
        "Local Features" => [
          { name: "Custom theme", value: false },
          { name: "Search opt-out", value: false },
          { name: "Local only posts", value: false },
          { name: "Long posts and markdown", value: false },
          { name: "Local quote posts", value: false },
        ],
        "User Management" => [
          { name: "Guest accounts", value: false },
          { name: "e-Newsletters", value: false },
          { name: "Analytics", value: false }
        ],
        "Plug-ins" => [

        ],
        "Bluesky Bridge" => [
          { name: "Enable bluesky bridge", value: false }
        ]
      }

      child_settings_data[parent_name].each_with_index do |child, child_index|
        # Skip if child setting already exists
        existing_child = ServerSetting.find_by(name: child[:name], parent_id: parent_setting.id)
        if existing_child
          puts "Skipping existing child setting: #{child[:name]}"
          next
        end
        
        ServerSetting.create!(name: child[:name], value: child[:value], position: child_index + 1, parent_id: parent_setting.id)
      end
    end
    puts "Done insertion of server settings & keywords"
  end
end
