namespace :communities do
  desc "Update community descriptions to replace 'home.channel.org/about' with 'home.channel.org/faqs'"
  task :update_description_urls, [:dry_run] => :environment do |t, args|
    dry_run = args[:dry_run] == 'true' || args[:dry_run] == '1'
    old_url = 'home.channel.org/about'
    new_url = 'home.channel.org/faqs'
    
    puts "Starting community description URL update task..."
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE UPDATE'}"
    puts "Replacing: '#{old_url}' with '#{new_url}'"
    puts "=" * 60
    
    # Count communities that need updating
    communities_to_update = Community.where("description LIKE ?", "%#{old_url}%").exclude_deleted_channels
    total_count = communities_to_update.count
    
    if total_count == 0
      puts "No communities found with '#{old_url}' in their descriptions."
      puts "Task completed."
      return
    end
    
    puts "Found #{total_count} communities that need updating."
    puts ""
    
    updated_count = 0
    error_count = 0
    batch_size = 100
    
    # Process in batches for better performance
    communities_to_update.find_in_batches(batch_size: batch_size) do |batch|
      puts "Processing batch of #{batch.size} communities..."
      
      batch.each do |community|
        begin
          old_description = community.description
          new_description = old_description.gsub(old_url, new_url)
          
          # Skip if no changes needed (shouldn't happen with our query, but safety first)
          next if old_description == new_description
          
          if dry_run
            puts "  [DRY RUN] Would update Community ID #{community.id} (#{community.name})"
            puts "    Old: #{old_description[0..100]}#{'...' if old_description.length > 100}"
            puts "    New: #{new_description[0..100]}#{'...' if new_description.length > 100}"
            puts ""
          else
            Community.transaction do
              community.update!(description: new_description)
              puts "  ✓ Updated Community ID #{community.id} (#{community.name})"
            end
          end
          
          updated_count += 1
          
        rescue StandardError => e
          error_count += 1
          puts "  ✗ Error updating Community ID #{community.id} (#{community.name}): #{e.message}"
        end
      end
      
      puts "Batch completed. Progress: #{[updated_count + error_count, total_count].min}/#{total_count}"
      puts ""
    end
    
    puts "=" * 60
    puts "Task Summary:"
    puts "Total communities found: #{total_count}"
    puts "Successfully #{dry_run ? 'analyzed' : 'updated'}: #{updated_count}"
    puts "Errors encountered: #{error_count}"
    
    if dry_run
      puts ""
      puts "This was a DRY RUN. No changes were made to the database."
      puts "To execute the updates, run: rake communities:update_description_urls"
    else
      puts ""
      puts "Database updates completed successfully!"
    end
  end
  
  desc "Preview communities that will be updated (dry run)"
  task preview_description_updates: :environment do
    Rake::Task["communities:update_description_urls"].invoke('true')
  end
  
  desc "Show detailed before/after comparison for communities that need updating"
  task show_description_changes: :environment do
    old_url = 'home.channel.org/about'
    new_url = 'home.channel.org/faqs'
    
    puts "Detailed comparison of description changes"
    puts "=" * 80
    
    communities_to_update = Community.where("description LIKE ?", "%#{old_url}%")
    
    if communities_to_update.empty?
      puts "No communities found with '#{old_url}' in their descriptions."
      return
    end
    
    communities_to_update.each do |community|
      puts "Community: #{community.name} (ID: #{community.id})"
      puts "Slug: #{community.slug}"
      puts ""
      puts "BEFORE:"
      puts community.description
      puts ""
      puts "AFTER:"
      puts community.description.gsub(old_url, new_url)
      puts "=" * 80
    end
  end
end