class Rack::Attack
  # Configure cache store (uses Rails.cache by default)
  # For production, use Redis for distributed rate limiting
  redis_url = if ENV['REDIS_PASSWORD'].present?
    "redis://:#{ENV['REDIS_PASSWORD']}@#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"
  else
    "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"
  end

  if redis_url.present?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: redis_url)
  else
    Rack::Attack.cache.store = Rails.cache
    if Rack::Attack.cache.store.is_a?(ActiveSupport::Cache::NullStore)
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    end
  end 

  # Allow localhost and trusted IPs from rate limiting
  # safelist('allow-localhost') do |req|
  #   req.ip == '127.0.0.1' || req.ip == '::1'
  # end

  PROTECTED_ENDPOINT_PATHS = %w[
    /api/v1/channels/my_channel
    /api/v1/collections/newsmast_collections
    /api/v1/collections
    /api/v1/collections/channel_feed_collections
    /api/v1/community_admins/boost_bot_accounts
    /api/v1/channels/mo_me_channels
    /api/v1/channels/channel_feeds
  ].freeze

  throttle('req/ip/protected-endpoints', limit: 20, period: 1.minute) do |req|
    req.ip if PROTECTED_ENDPOINT_PATHS.include?(req.path)
  end

  # Throttle all requests by IP (20 requests per minute)
  # throttle('req/ip', limit: 20, period: 5.minute) do |req|
  #   req.ip
  # end

  # Block requests from suspicious IPs
  blocklist('block-suspicious-ips') do |req|
    req.user_agent.blank?
  end

  # Exponential backoff for repeat offenders
  Rack::Attack.blocklist('penalize-repeat-offenders') do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 5, findtime: 10.minutes, bantime: 1.hour) do
      Rack::Attack.cache.count("penalize-#{req.ip}", 10.minutes) > 5
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'RateLimit-Limit' => match_data[:limit].to_s,
      'RateLimit-Remaining' => '0',
      'RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }

    [429, headers, [{ error: 'Rate limit exceeded. Try again later.' }.to_json]]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |env|
    [403, { 'Content-Type' => 'application/json' }, [{ error: 'Forbidden' }.to_json]]
  end

  # Log blocked and throttled requests
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    
    if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
      Rails.logger.warn "[Rack::Attack][#{req.env['rack.attack.match_type']}] " \
                        "IP: #{req.ip}, Path: #{req.path}, Matched: #{req.env['rack.attack.matched']}"
    end
  end
end