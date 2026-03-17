require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq-scheduler'
require 'uri'

db = (ENV['REDIS_DB'].presence || ENV['SIDEKIQ_REDIS_DB'].presence || '0').to_i

redis_url = if ENV['REDIS_PASSWORD'].present?
  "redis://:#{ENV['REDIS_PASSWORD']}@#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{db}"
else
  "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{db}"
end

Sidekiq.configure_server do |config|
  config.redis = {
    url: redis_url
  }
end
 
Sidekiq.configure_client do |config|
  config.redis = {
    url: redis_url
  }
end