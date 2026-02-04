module Scheduler
  class FollowBlueskyBotScheduler
    include Sidekiq::Worker
    include ApplicationHelper

    sidekiq_options retry: 0, lock: :until_executed, lock_ttl: 15.minutes.to_i, queue: :scheduler

    def perform
      return unless ServerSetting.find_by(name: 'Automatic Bluesky bridging for new users')&.value

      if is_channel_instance?
        Rails.logger.info('Processing communities for automatic Bluesky bridging')
        ChannelBlueskyBridgeService.new.process_communities
      else
        Rails.logger.info('Processing users for automatic Bluesky bridging')
        NonChannelBlueskyBridgeService.new.process_users
      end

    end

  end
end
