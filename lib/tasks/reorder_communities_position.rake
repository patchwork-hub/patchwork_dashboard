namespace :communities do
  desc "Reorder communities position by created_at (oldest first), scoped by channel_type"
  task reorder_communities_position: :environment do
    channel_types = Community.where(deleted_at: nil).distinct.pluck(:channel_type)

    channel_types.each do |channel_type|
      communities = Community.where(channel_type: channel_type, deleted_at: nil).order(created_at: :asc)
      puts "Reordering #{communities.count} communities for channel_type: #{channel_type}"

      communities.each_with_index do |community, index|
        new_position = index + 1
        community.update_column(:position, new_position)
        puts "  #{community.name} => position #{new_position}"
      end
    end

    puts "Done! All communities have been reordered by created_at."
  end
end
