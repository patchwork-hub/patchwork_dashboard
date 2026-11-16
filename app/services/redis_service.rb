# frozen_string_literal: true

require 'redis'
require 'redis-namespace'

class RedisService
  def self.client(namespace: ENV.fetch('REDIS_NAMESPACE', nil))
    db = (ENV['REDIS_DB'].presence || ENV['SIDEKIQ_REDIS_DB'].presence || '0').to_i

    redis = if ENV['REDIS_URL'].present?
      Redis.new(
        url: ENV['REDIS_URL'],
        driver: (ENV['REDIS_DRIVER'].presence || 'hiredis').to_sym
      )
    else
      Redis.new(
        host: ENV.fetch('REDIS_HOST', 'localhost'),
        port: ENV.fetch('REDIS_PORT', 6379),
        password: ENV.fetch('REDIS_PASSWORD', nil),
        db: db
      )
    end

    @client ||= Redis::Namespace.new(namespace, redis: redis)
  end
end