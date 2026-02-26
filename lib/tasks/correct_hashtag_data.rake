namespace :correct_hashtag_data do
  desc "Create missing TagFollow records and remove unexpected ones for community boost bots (Background Job)"
  task fix_tag_follows: :environment do
    puts "Enqueuing CorrectHashtagDataJob..."
    CorrectHashtagDataJob.perform_later
    puts "CorrectHashtagDataJob enqueued successfully! Please check sidekiq/worker logs for output."
  end
end
