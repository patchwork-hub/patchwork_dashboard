namespace :check_hashtag_data do
  desc "Check for unexpected tag follows for community boost bots (Background Job)"
  task check_unexpected_tag_follows: :environment do
    puts "Enqueuing CheckHashtagDataJob..."
    CheckHashtagDataJob.perform_later
    puts "CheckHashtagDataJob enqueued successfully! Please check sidekiq/worker logs for output."
  end
end
