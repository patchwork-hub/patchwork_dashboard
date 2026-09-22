# Expose the task-local prometheus_exporter collector through the existing Puma port.
# This endpoint MUST be blocked at the public ALB (path /metrics and /metrics/).
require "net/http"

class MetricsController < ActionController::Base
  def index
    return head :not_found unless ENV["MASTODON_PROMETHEUS_EXPORTER_ENABLED"] == "true"

    uri = URI("http://127.0.0.1:9394/metrics")
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 3) do |http|
      http.get(uri.request_uri)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Metrics collector returned HTTP #{response.code}")
      return head :service_unavailable
    end

    self.response.headers["Cache-Control"] = "no-store"
    render plain: response.body, content_type: "text/plain; version=0.0.4; charset=utf-8"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, IOError => e
    Rails.logger.warn("Metrics collector unavailable: #{e.class}")
    head :service_unavailable
  end
end
