class QueryProfiler
  def initialize(app)
    @app = app
  end

  def call(env)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next unless payload[:duration] # Skip if no duration
      queries << {
        sql: payload[:sql],
        duration: payload[:duration].to_f.round(2)
      }
    end

    status, headers, response = @app.call(env)
    
    # Ensure we unsubscribe to avoid memory leaks
    ActiveSupport::Notifications.unsubscribe(subscriber)
    
    if queries.any?
      headers["X-SQL-Profile"] = {
        total_queries: queries.size,
        total_time: queries.sum { |q| q[:duration] }.round(2),
        queries: queries
      }.to_json
    end

    [status, headers, response]
    rescue => e
    Rails.logger.error "QueryProfiler Error: #{e.message}"
    [500, { 'Content-Type' => 'text/plain' }, ["QueryProfiler encountered an error"]]
  end
end