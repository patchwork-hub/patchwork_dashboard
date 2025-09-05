namespace :newsmast_relays do
  desc "Create relays for hashtags in newsmast channels"
  task create: :environment do
    puts "Starting relay creation for newsmast channels..."
    
    # Find owner user to get the token
    puts "DEBUG: Looking for Owner role..."
    owner_role = UserRole.find_by(name: 'Owner')
    puts "DEBUG: Owner role found: #{owner_role.inspect}"
    
    owner_user = User.find_by(role: owner_role)
    puts "DEBUG: Owner user found: #{owner_user.inspect}"
    
    unless owner_user
      puts "Owner user not found. Aborting relay creation."
      return
    end
    
    puts "DEBUG: Fetching OAuth token for user ID: #{owner_user.id}"
    token = fetch_oauth_token(owner_user.id)
    puts "DEBUG: Token received: #{token ? 'YES' : 'NO'} (length: #{token&.length})"
    
    api_base_url = ENV.fetch('MASTODON_INSTANCE_URL')
    puts "DEBUG: API base URL: #{api_base_url}"
    
    # Fetch all newsmast channels
    puts "DEBUG: Querying for newsmast channels..."
    newsmast_channels = Community.where(channel_type: 'newsmast')
    puts "DEBUG: Found #{newsmast_channels.count} newsmast channels"
    puts "DEBUG: Available channel types: #{Community.channel_types.inspect}"
    
    if newsmast_channels.empty?
      puts "No newsmast channels found."
      puts "DEBUG: All communities: #{Community.pluck(:name, :channel_type)}"
      return
    end
    
    total_channels = newsmast_channels.count
    processed_count = 0
    success_count = 0
    error_count = 0
    
    puts "Found #{total_channels} newsmast channels"
    
    newsmast_channels.find_each do |community|
      processed_count += 1
      puts "[#{processed_count}/#{total_channels}] Processing community: #{community.name} (#{community.slug})"
      puts "DEBUG: Community ID: #{community.id}, Channel Type: #{community.channel_type}"
      
      # Fetch hashtags for this community
      hashtags = CommunityHashtag.where(patchwork_community_id: community.id)
      puts "DEBUG: Query: CommunityHashtag.where(patchwork_community_id: #{community.id})"
      puts "DEBUG: Found #{hashtags.count} hashtags for community #{community.id}"
      
      if hashtags.empty?
        puts "  → No hashtags found for community: #{community.name}"
        puts "DEBUG: All hashtags in system: #{CommunityHashtag.pluck(:patchwork_community_id, :hashtag)}"
        next
      end
      
      puts "  → Found #{hashtags.count} hashtags"
      
      hashtags.each do |hashtag|
        puts "DEBUG: Processing hashtag: #{hashtag.hashtag} (ID: #{hashtag.id})"
        begin
          result = create_relay(hashtag.hashtag, token, api_base_url)
          puts "DEBUG: create_relay returned: #{result.inspect}"
          puts "  ✓ Created relay for hashtag: ##{hashtag.hashtag}"
          success_count += 1
        rescue StandardError => e
          puts "  ✗ Failed to create relay for hashtag: ##{hashtag.hashtag} - #{e.message}"
          puts "DEBUG: Full error: #{e.class}: #{e.message}"
          puts "DEBUG: Backtrace: #{e.backtrace.first(5).join("\n")}"
          error_count += 1
        end
      end
    end
    
    # Summary
    puts "\n=== Relay creation summary ==="
    puts "Total channels processed: #{processed_count}"
    puts "Relays created successfully: #{success_count}"
    puts "Errors encountered: #{error_count}"
    puts "Relay creation completed."
  end
  
  private
  
  def fetch_oauth_token(user_id)
    puts "DEBUG: Calling GenerateAdminAccessTokenService for user_id: #{user_id}"
    token_service = GenerateAdminAccessTokenService.new(user_id)
    result = token_service.call
    puts "DEBUG: Token service result: #{result.inspect}"
    result
  end
  
  def create_relay(hashtag_name, token, api_base_url)
    inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
    puts "DEBUG: Checking if relay exists with inbox_url: #{inbox_url}"
    
    existing_relay = Relay.find_by(inbox_url: inbox_url)
    puts "DEBUG: Existing relay found: #{existing_relay.inspect}"
    
    unless existing_relay
      puts "DEBUG: Creating new relay with CreateRelayService"
      puts "DEBUG: Parameters - api_base_url: #{api_base_url}, token present: #{!token.nil?}, hashtag: #{hashtag_name}"
      
      service = CreateRelayService.new(api_base_url, token, hashtag_name)
      result = service.call
      puts "DEBUG: CreateRelayService result: #{result.inspect}"
      result
    else
      puts "  → Relay already exists for hashtag: ##{hashtag_name}"
      return existing_relay
    end
  end
end