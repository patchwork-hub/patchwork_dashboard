module Scheduler
  class FollowBlueskyBotScheduler
    include Sidekiq::Worker
    include ApplicationHelper

    sidekiq_options retry: 0, lock: :until_executed, lock_ttl: 15.minutes.to_i, queue: :scheduler

    def perform
      return unless ServerSetting.find_by(name: 'Enable bluesky bridge')&.value

      if is_channel_dashboard?
        ChannelBlueskyBridgeService.new.process_communities
      else
        NonChannelBlueskyBridgeService.new.process_users
      end

    end

  end
end