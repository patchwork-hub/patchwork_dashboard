require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq-scheduler'
require 'uri'

db = (ENV['SIDEKIQ_REDIS_DB'].presence || ENV['REDIS_DB'].presence || '0').to_i

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

if ENV.fetch('MASTODON_PROMETHEUS_EXPORTER_ENABLED', 'false').to_s == 'true'
  require 'prometheus_exporter'
  require 'prometheus_exporter/instrumentation'

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add PrometheusExporter::Instrumentation::Sidekiq
    end
  end

  if ENV.fetch('MASTODON_PROMETHEUS_EXPORTER_SIDEKIQ_DETAILED_METRICS', 'false').to_s == 'true'
    PrometheusExporter::Instrumentation::SidekiqProcess.start if defined?(PrometheusExporter::Instrumentation::SidekiqProcess)
    PrometheusExporter::Instrumentation::SidekiqStats.start if defined?(PrometheusExporter::Instrumentation::SidekiqStats)
    PrometheusExporter::Instrumentation::SidekiqQueue.start if defined?(PrometheusExporter::Instrumentation::SidekiqQueue)
  end
end