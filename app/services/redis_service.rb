# frozen_string_literal: true

require 'redis'
require 'redis-namespace'

class RedisService
  def self.client(namespace: ENV.fetch('REDIS_NAMESPACE', nil))
    @client ||= Redis::Namespace.new(
      namespace,
      redis: Redis.new(
        url: ENV['REDIS_URL'],
        password: ENV.fetch('REDIS_PASSWORD', nil)
      )
    )
  end
end