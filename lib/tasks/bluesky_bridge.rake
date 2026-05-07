namespace :bluesky_bridge do
  desc "Check follow status for users with did_value and bluesky bridge enabled"
  task check_follow_status: :environment do
    target_account = Account.find_by(username: 'bsky.brid.gy', domain: 'bsky.brid.gy')

    if target_account.nil?
      puts "Target account not found. Set ACCOUNT_ID=<id> or ensure @bsky.brid.gy@bsky.brid.gy exists."
      next
    end

    local_domain = ENV['LOCAL_DOMAIN'].to_s
    base_domain = local_domain.split('.').last(2).join('.') if local_domain.include?('.')

    users = User.where.not(did_value: [nil, '']).where(bluesky_bridge_enabled: true).includes(:account)

    puts "Checking follow status for #{users.count} users against account_id=#{target_account.id}..."

    users.find_each do |user|

      did_value = user.did_value
      url = "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=#{CGI.escape(did_value)}"
      response = HTTParty.get(url, timeout: 10)
      if response.code != 200
        puts "user_id=#{user.id} username=#{user.account&.username} skipped: failed to fetch profile with did_value=#{did_value}"
        next
      end

      handle_name = response.dig('handle')

      if handle_name.nil? || handle_name.empty?
        puts "user_id=#{user.id} username=#{user.account&.username} skipped: handle not found in profile response for did_value=#{did_value}"
        next
      end

      account = user.account

      if account.nil?
        puts "user_id=#{user.id} skipped: account is missing"
        next
      end

      if account.id == target_account.id
        puts "user_id=#{user.id} username=#{account.username} skipped: target account itself"
        next
      end

      if account.username.blank?
        puts "user_id=#{user.id} skipped: username is blank"
        next
      end

      relationship_data = AccountRelationshipsService.new.call(account, target_account.id)
      relationship = relationship_data.is_a?(Array) ? relationship_data.last : nil
      following = relationship.present? ? relationship['following'] : nil


      if handle_name.end_with?(".ap.brid.gy")
        puts "*** user_id=#{user.id} username=#{account.username} handle=#{handle_name} ***"
        UnfollowService.new.call(account, target_account)
        sleep 1.minutes
      end

      if relationship&.[]('following') == false
        puts "*** user_id=#{user.id} username=#{account.username} following? =#{relationship&.[]('following')} ***"

        FollowService.new.call(account, target_account)

        # Re-check relationship to avoid sending DM when follow failed.
        refreshed_data = AccountRelationshipsService.new.call(account, target_account.id)
        refreshed_relationship = refreshed_data.is_a?(Array) ? refreshed_data.last : nil

        if refreshed_relationship&.[]('following')
          if base_domain.present?
            token = GenerateAdminAccessTokenService.new(user.id).call

            if token.present?
              status_params = {
                "in_reply_to_id": nil,
                "language": "en",
                "media_ids": [],
                "poll": nil,
                "sensitive": false,
                "spoiler_text": "",
                "status": "@bsky.brid.gy@bsky.brid.gy username #{account.username}.#{base_domain}",
                "visibility": "direct"
              }

              PostStatusService.new.call(token: token, options: status_params)
            else
              puts "user_id=#{user.id} username=#{account.username} skipped DM: token is missing"
            end
          else
            puts "user_id=#{user.id} username=#{account.username} skipped DM: LOCAL_DOMAIN is invalid"
          end
        else
          puts "user_id=#{user.id} username=#{account.username} follow attempt did not complete"
        end
      end

      puts "user_id=#{user.id} username=#{account.username} following=#{following.inspect}"
    rescue StandardError => e
      puts "user_id=#{user.id} username=#{account&.username} error=#{e.message}"
    end

    puts 'Follow status check completed.'
  end
end
