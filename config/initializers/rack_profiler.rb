if Rails.env.development?
  begin
    require 'rack-mini-profiler'

    # Start the profiler
    ::Rack::MiniProfilerRails.initialize!(Rails.application)

    # Optional: Customize settings
    Rack::MiniProfiler.config.position = 'bottom' # display at bottom of page
  rescue LoadError => e
    Rails.logger.warn "rack-mini-profiler not available: #{e.message}"
  end
end