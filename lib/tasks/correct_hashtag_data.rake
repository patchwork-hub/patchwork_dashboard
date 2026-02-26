namespace :correct_hashtag_data do
  desc "Create missing TagFollow records and remove unexpected ones for community boost bots"
  task fix_tag_follows: :environment do
    puts "Starting data correction for missing tag follows..."

    results = CommunityAdmin
      .where(is_boost_bot: true)
      .where.not(account_id: nil)
      .joins(:community)
      .joins("INNER JOIN patchwork_communities_hashtags pch ON pch.patchwork_community_id = patchwork_communities_admins.patchwork_community_id")
      .joins("LEFT JOIN tags t ON lower(t.name) = lower(pch.hashtag)")
      .joins("LEFT JOIN tag_follows tf ON tf.tag_id = t.id AND tf.account_id = patchwork_communities_admins.account_id")
      .select(
        "patchwork_communities.name AS community_name",
        "patchwork_communities_admins.account_id AS bot_account_id",
        "pch.hashtag AS community_tag",
        "t.id AS verified_tag_id",
        "CASE WHEN tf.id IS NOT NULL THEN true ELSE false END AS is_followed"
      )

    count = 0
    
    results.each do |record|
      next if record.is_followed

      begin
        tag_id = record.verified_tag_id
        
        if tag_id.nil?
          clean_hashtag = record.community_tag.delete_prefix('#')
          tag = Tag.find_or_create_by!(name: clean_hashtag)
          tag_id = tag.id
          puts "  -> Created missing Tag record for: #{clean_hashtag}"
        end
        
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "INSERT INTO tag_follows (tag_id, account_id, created_at, updated_at) VALUES (?, ?, NOW(), NOW()) ON CONFLICT (account_id, tag_id) DO NOTHING",
            tag_id, record.bot_account_id
          ])
        )
        
        puts "✅ Created follow -> Community: '#{record.community_name}' | Bot ID: #{record.bot_account_id} | Tag: #{record.community_tag}"
        count += 1
      rescue => e
        puts "❌ Error creating follow -> Community: '#{record.community_name}' | Tag: #{record.community_tag} | Error: #{e.message}"
      end
    end

    puts "\nFinished data correction. Successfully created #{count} missing tag follows."

    puts "\n--- Removing unexpected tag follows ---"
    count_unexpected = 0

    results_unexpected = CommunityAdmin
      .where(is_boost_bot: true)
      .where.not(account_id: nil)
      .joins(:community)
      .joins("INNER JOIN tag_follows tf ON tf.account_id = patchwork_communities_admins.account_id")
      .joins("INNER JOIN tags t ON t.id = tf.tag_id")
      .joins("LEFT JOIN patchwork_communities_hashtags pch ON pch.patchwork_community_id = patchwork_communities_admins.patchwork_community_id AND lower(pch.hashtag) = lower(t.name)")
      .select(
        "patchwork_communities.name AS community_name",
        "patchwork_communities_admins.account_id AS bot_account_id",
        "t.id AS tag_id",
        "t.name AS tag_name",
        "CASE WHEN pch.id IS NULL THEN true ELSE false END AS is_unexpected"
      )

    results_unexpected.each do |record|
      if record.is_unexpected
        begin
          ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.sanitize_sql_array([
              "DELETE FROM tag_follows WHERE tag_id = ? AND account_id = ?",
              record.tag_id, record.bot_account_id
            ])
          )
          puts "🗑️ Removed unexpected follow -> Community: '#{record.community_name}' | Bot ID: #{record.bot_account_id} | Tag: #{record.tag_name}"
          count_unexpected += 1
        rescue => e
          puts "❌ Error removing unexpected follow -> Community: '#{record.community_name}' | Tag: #{record.tag_name} | Error: #{e.message}"
        end
      end
    end

    puts "\nFinished unexpected follow cleanup. Successfully removed #{count_unexpected} unexpected tag follows."
  end
end
