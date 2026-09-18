require "test_helper"
require "set"

class KeywordFilterGroupRedisTest < ActiveSupport::TestCase
  class FakeRedis
    attr_reader :hashes, :scan_count, :sets

    def initialize
      @hashes = Hash.new { |hash, key| hash[key] = {} }
      @sets = Hash.new { |hash, key| hash[key] = Set.new }
      @scan_count = 0
    end

    def smembers(key)
      sets[key].to_a
    end

    def hscan_each(key)
      @scan_count += 1
      hashes[key].each { |field, value| yield field, value }
    end

    def pipelined
      yield self
    end

    def sadd?(key, value)
      sets[key].add(value)
    end

    def hmget(key, *fields)
      fields.map { |field| hashes[key][field] }
    end

    def hset(key, field, value)
      hashes[key][field] = value
    end
  end

  test "backfills a group index and avoids rescanning the hash" do
    redis = FakeRedis.new
    redis.hashes["content_filters"] = {
      "one:keyword" => { group_id: 1, is_active: true }.to_json,
      "two:keyword" => { group_id: 2, is_active: true }.to_json
    }

    RedisService.stub(:client, redis) do
      KeywordFilterGroup.update_redis_group("content_filters", 1, false)
      KeywordFilterGroup.update_redis_group("content_filters", 1, true)
    end

    assert_equal 1, redis.scan_count
    assert_equal true, JSON.parse(redis.hashes["content_filters"]["one:keyword"])["is_active"]
    assert_equal true, JSON.parse(redis.hashes["content_filters"]["two:keyword"])["is_active"]
  end
end
