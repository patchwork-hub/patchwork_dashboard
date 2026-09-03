if Rails.env.production? && ENV.fetch('LOGRAGE_ENABLED', 'false').to_s == 'true'
  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.base_controller_class = ['ActionController::Base']
    config.lograge.logger = ActiveSupport::Logger.new($stdout)
    config.lograge.formatter = Lograge::Formatters::Json.new

    config.lograge.ignore_actions = ['HealthCheck::HealthCheckController#show']

    config.lograge.custom_payload do |controller|
      payload = {
        request_id: controller.request.request_id,
        user_id: controller.respond_to?(:current_user) ? controller.current_user&.id : nil,
        ip: controller.request.remote_ip
      }

      payload.compact
    end

    config.lograge.custom_options = lambda do |event|
      payload = event.payload
      filtered = payload[:params].to_h.except('controller', 'action', 'format') if payload[:params].respond_to?(:except)

      {
        controller: payload[:controller],
        action: payload[:action],
        status: payload[:status],
        duration_ms: event.duration.round(2),
        db_runtime_ms: payload[:db_runtime],
        view_runtime_ms: payload[:view_runtime],
        params: filtered.presence
      }.compact
    end
  end
end
