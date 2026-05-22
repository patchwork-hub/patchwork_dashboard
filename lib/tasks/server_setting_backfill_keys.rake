namespace :server_setting do
  desc "Backfill stable keys for existing ServerSetting records"
  task backfill_keys: :environment do
    puts "Starting backfill of ServerSetting keys..."

    # Maps current display name → stable key
    name_to_key = {
      # Parent groups
      "Spam Block"           => "spam_block",
      "Content Moderation"   => "content_moderation",
      "Federation"           => "federation",
      "Local Features"       => "local_features",
      "User Management"      => "user_management",
      "Plug-ins"             => "plugins",
      "Bluesky Bridge"       => "bluesky_bridge",
      "Email Branding"       => "email_branding",

      # Child settings
      "Spam filters"                             => "spam_filters",
      "Sign up challenge"                        => "signup_challenge",
      "Content filters"                          => "content_filters",
      "Bluesky"                                  => "bluesky",
      "Threads"                                  => "threads",
      "Live blocklist"                           => "live_blocklist",
      "Custom theme"                             => "custom_theme",
      "Automatic Search Opt-out"                 => "search_opt_out",
      "Local only posts"                         => "local_only_posts",
      "Long posts"                               => "long_posts",
      "Local quote posts"                        => "local_quote_posts",
      "Guest accounts"                           => "guest_accounts",
      "e-Newsletters"                            => "newsletters",
      "Analytics"                                => "analytics",
      "Automatic Bluesky bridging for new users" => "bluesky_bridge_auto",
    }

    updated = 0
    skipped = 0
    not_found = 0

    name_to_key.each do |name, key|
      settings = ServerSetting.where(name: name, key: nil)

      if settings.any?
        settings.each do |setting|
          setting.update_column(:key, key)
          puts "  ✓ '#{name}' → key: '#{key}' (id: #{setting.id})"
          updated += 1
        end
      else
        existing = ServerSetting.find_by(name: name)
        if existing&.key.present?
          puts "  ⊘ '#{name}' already has key: '#{existing.key}'"
          skipped += 1
        else
          puts "  ✗ '#{name}' not found in database"
          not_found += 1
        end
      end
    end

    # Report any settings without keys
    orphans = ServerSetting.where(key: nil)
    if orphans.any?
      puts "\n⚠ Settings without keys:"
      orphans.each do |s|
        puts "  - id: #{s.id}, name: '#{s.name}', parent_id: #{s.parent_id}"
      end
    end

    puts "\nDone! Updated: #{updated}, Skipped: #{skipped}, Not found: #{not_found}"
  end
end
