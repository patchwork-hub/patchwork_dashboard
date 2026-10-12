module Scheduler
  class CommunityCleanupScheduler
    include Sidekiq::Worker
    sidekiq_options retry: 0, queue: :scheduler

    def perform
      communities = Community.where.not(deleted_at: nil)
                            .where('deleted_at <= ?', 30.days.ago)
                            
      if communities.empty?
        Rails.logger.info '[CommunityCleanupScheduler] No communities to clean up.'
        return
      end

      Rails.logger.info "[CommunityCleanupScheduler] Starting cleanup for #{communities.count} communities..."

      communities.find_each do |community|
        begin
          account_ids = community.community_admins.pluck(:account_id).compact.uniq

          Rails.logger.info "[CommunityCleanupScheduler] Deleting community ##{community.id}..."

          response = DeleteCommunityInstanceService.new.call(community)

          if response
            Rails.logger.info "[CommunityCleanupScheduler] Successfully called DeleteCommunityInstanceService for community ##{community.id}."
            ActiveRecord::Base.transaction { community.destroy! }

            accounts_by_id = Account.where(id: account_ids).index_by(&:id)
            account_ids.each do |account_id|
              account = accounts_by_id[account_id]
              if account
                AccountDeletionService.new.call(account)
                Rails.logger.info "[CommunityCleanupScheduler] Enqueued deletion for account ##{account_id}."
              else
                Rails.logger.warn "[CommunityCleanupScheduler] Account ##{account_id} not found. Skipping deletion."
              end
            end
          else
            Rails.logger.warn "[CommunityCleanupScheduler] Skipping destroy for community ##{community.id} due to service call failure."
          end
        rescue StandardError => e
          Rails.logger.error "[CommunityCleanupScheduler] Error deleting community #{community.id}: #{e.message}"
        end
      end

      Rails.logger.info '[CommunityCleanupScheduler] Cleanup completed.'
    end
  end
end
