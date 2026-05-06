module Scheduler
  class CommunityCleanupScheduler
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
          ActiveRecord::Base.transaction do
            account_ids = community&.community_admins&.pluck(:account_id)

            Rails.logger.info "[CommunityCleanupScheduler] Deleting community ##{community.id}..."

            response = DeleteCommunityInstanceService.new.call(community)

            if response
              Rails.logger.info "[CommunityCleanupScheduler] Successfully called DeleteCommunityInstanceService for community ##{community.id}."
              community.destroy

              account_ids.compact.uniq.each do |account_id|
                if Account.exists?(account_id)
                  AccountDeletionService.new.call(Account.find(account_id))
                  Rails.logger.info "[CommunityCleanupScheduler] Enqueued deletion for account ##{account_id}."
                else
                  Rails.logger.warn "[CommunityCleanupScheduler] Account ##{account_id} not found. Skipping deletion."
                end
              end
            else
              Rails.logger.warn "[CommunityCleanupScheduler] Skipping destroy for community ##{community.id} due to service call failure."
            end
            sleep(0.05)
          end
        rescue => e
          Rails.logger.error "[CommunityCleanupScheduler] Error deleting community #{community.id}: #{e.message}"
        end
      end

      Rails.logger.info '[CommunityCleanupScheduler] Cleanup completed.'
    end
  end
end
