module Scheduler
  class FetchSpamKeywordScheduler
    include Sidekiq::Worker
    sidekiq_options retry: 0, queue: :scheduler

    def perform
      KeywordFiltersJob.perform_now(ServerSetting::KEY_SPAM_FILTERS)
    end
  end
end
