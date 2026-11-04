require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq-scheduler'
require 'uri'

db = (ENV['SIDEKIQ_REDIS_DB'].presence || ENV['REDIS_DB'].presence || '0').to_i

redis_url = if ENV['REDIS_URL'].present?
  ENV['REDIS_URL']
elsif ENV['REDIS_PASSWORD'].present?
  "redis://:#{ENV['REDIS_PASSWORD']}@#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{db}"
else
  "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{db}"
end

redis_options = {
  url: redis_url,
  driver: (ENV['REDIS_DRIVER'].presence || 'hiredis').to_sym
}

Sidekiq.configure_server do |config|
  config.redis = redis_options
end
 
Sidekiq.configure_client do |config|
  config.redis = redis_options
end