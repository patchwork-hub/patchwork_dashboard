namespace :server_setting do
  desc "Update ServerSetting names"
  task update_search_opt_out: :environment do
    puts "Starting update ServerSetting names.."

    updates = {
      "Automatic Search Opt-in" => "Automatic Search Opt-out"
    }

    updates.each do |old_name, new_name|
      update_setting_name(old_name, new_name)
    end

    puts "End update ServerSetting names!"
  end

  def update_setting_name(old_name, new_name)
    setting = ServerSetting.find_by(name: old_name)

    if setting.present?
      setting.update!(name: new_name)
      puts "Updated ServerSetting: '#{old_name}' -> '#{new_name}'"
    else
      puts "No ServerSetting found with name '#{old_name}'"
    end
  end
end
