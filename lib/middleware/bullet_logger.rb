class BulletLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    warnings = []
    subscriber = ActiveSupport::Notifications.subscribe('n_plus_one_query') do |event|
      warnings << event.payload[:message] rescue nil
    end

    status, headers, response = @app.call(env)
    
    ActiveSupport::Notifications.unsubscribe(subscriber)
    
    if warnings.any?
      headers['X-N-Plus-One-Warnings'] = warnings.to_json
    end

    [status, headers, response]
  rescue => e
    Rails.logger.error "BulletLogger Error: #{e.message}"
    @app.call(env) # Fallback to original request
  end
end