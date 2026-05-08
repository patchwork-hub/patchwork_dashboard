module Scheduler
  class FetchContentKeywordScheduler
    include Sidekiq::Worker
    sidekiq_options retry: 0, queue: :scheduler

    def perform
      KeywordFiltersJob.perform_now(ServerSetting::KEY_CONTENT_FILTERS)
    end
  end
end
