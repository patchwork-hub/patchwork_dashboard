if ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
  require 'opentelemetry'
  require 'opentelemetry/sdk'
  require 'opentelemetry/exporter/otlp'

  require 'opentelemetry-instrumentation-rack'
  require 'opentelemetry-instrumentation-rails'
  require 'opentelemetry-instrumentation-active_job'
  require 'opentelemetry-instrumentation-sidekiq'
#   require 'opentelemetry-instrumentation-pg'  # Disabled to prevent recursion
  require 'opentelemetry-instrumentation-faraday'
  require 'opentelemetry-instrumentation-redis'
  require 'opentelemetry-instrumentation-concurrent_ruby'

  enable_net_http = ENV.fetch('OTEL_ENABLE_NET_HTTP_INSTRUMENTATION', Rails.env.production? ? 'true' : 'false') == 'true'
  require 'opentelemetry-instrumentation-net_http' if enable_net_http

  OpenTelemetry::SDK.configure do |config|
    config.service_name = ENV.fetch('OTEL_SERVICE_NAME_PREFIX', 'patchwork-dashboard')
    config.service_version = ENV.fetch('APP_VERSION', 'local')

    config.use 'OpenTelemetry::Instrumentation::Rack'
    config.use 'OpenTelemetry::Instrumentation::Rails'
    config.use 'OpenTelemetry::Instrumentation::ActiveJob'
    config.use 'OpenTelemetry::Instrumentation::Sidekiq'
    config.use 'OpenTelemetry::Instrumentation::PG'
    config.use 'OpenTelemetry::Instrumentation::Faraday'
    config.use 'OpenTelemetry::Instrumentation::Redis'
    config.use 'OpenTelemetry::Instrumentation::ConcurrentRuby'
    config.use 'OpenTelemetry::Instrumentation::Net::HTTP' if enable_net_http

    config.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318/v1/traces'),
          timeout: 10
        )
      )
    )
  end
end
