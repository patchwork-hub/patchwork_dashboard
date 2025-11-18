namespace :server_setting do
  desc "Delete specific ServerSetting rows"
  task delete_rows: :environment do
    puts "Starting delete ServerSetting rows..."

    delete_rows = [
      "No-Boost Channels",
      "No-Boost"
    ]

    delete_rows.each do |name|
      if (setting = ServerSetting.find_by(name: name))
        setting.destroy!
        puts "Deleted server setting: #{name}"
      else
        puts "Server setting not found: #{name}"
      end
    end

    puts "End delete ServerSetting rows!"
  end
end
