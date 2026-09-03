if ENV.fetch('MASTODON_PROMETHEUS_EXPORTER_ENABLED', 'false').to_s == 'true'
  require 'prometheus_exporter'
  require 'prometheus_exporter/middleware'

  unless Rails.env.test?
    Rails.application.middleware.unshift PrometheusExporter::Middleware
  end

  if ENV.fetch('MASTODON_PROMETHEUS_EXPORTER_LOCAL', 'false').to_s == 'true'
    require 'prometheus_exporter/instrumentation'
    PrometheusExporter::Instrumentation::Process.start
  end
end
