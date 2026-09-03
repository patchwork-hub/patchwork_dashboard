require 'minitest/autorun'
require 'prometheus_exporter'
require 'prometheus_exporter/middleware'
require 'prometheus_exporter/instrumentation'

class MonitoringTest < Minitest::Test
  def test_prometheus_exporter_gem_is_available
    assert defined?(PrometheusExporter::Middleware), 'Prometheus exporter middleware should be installed and loaded'
    assert defined?(PrometheusExporter::Instrumentation::Sidekiq), 'Prometheus Sidekiq instrumentation should be installed and loaded'
  end
end
