class Rack::Attack
  # Configure cache store (uses Rails.cache by default)
  # For production, use Redis for distributed rate limiting
  if ENV['REDIS_URL'].present?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_URL'])
  else
    Rack::Attack.cache.store = Rails.cache
    if Rack::Attack.cache.store.is_a?(ActiveSupport::Cache::NullStore)
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    end
  end

  # Allow localhost and trusted IPs from rate limiting
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  # Throttle all requests by IP (20 requests per minute)
  throttle('req/ip', limit: 20, period: 5.minute) do |req|
    req.ip
  end

  # Block requests from suspicious IPs
  blocklist('block-suspicious-ips') do |req|
    # Block requests without user agent
    req.user_agent.nil? || req.user_agent.blank?
  end

  # Exponential backoff for repeat offenders using Allow2Ban
  blocklist('penalize-repeat-offenders') do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 5.minute, bantime: 6.hour) do
      false
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data'] || {}
    now = match_data[:epoch_time] || Time.now.to_i
    limit = match_data[:limit] || 0
    period = match_data[:period] || 1

    reset_at =
      if period.positive?
        now + (period - now % period)
      else
        now
      end

    headers = {
      'RateLimit-Limit' => limit.to_s,
      'RateLimit-Remaining' => '0',
      'RateLimit-Reset' => reset_at.to_s,
      'Content-Type' => 'application/json'
    }

    body = { error: 'Rate limit exceeded. Try again later.' }.to_json
    [429, headers, [body]]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |env|
    body = { error: 'Forbidden' }.to_json
    [403, { 'Content-Type' => 'application/json' }, [body]]
  end

  # Log blocked and throttled requests
  # Track throttled requests for Allow2Ban
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    match_type = req.env['rack.attack.match_type']

    if match_type == :throttle && req.env['rack.attack.matched'] == 'req/ip'
      Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 5, findtime: 1.minute, bantime: 6.hour) do
        true
      end
    end
    
    if [:throttle, :blocklist].include?(match_type)
      Rails.logger.warn "[Rack::Attack][#{match_type}] " \
                        "IP: #{req.ip}, Path: #{req.path}, Matched: #{req.env['rack.attack.matched']}"
    end
  end
end