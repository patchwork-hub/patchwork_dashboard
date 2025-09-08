if Rails.env.development? || Rails.env.local?
  require 'stringio'
  require 'logger'
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = false # Disable HTML injection for APIs

  # For Postman/N+1 detection in logs:
  ActiveSupport::Notifications.subscribe('n_plus_one_query') do |event|
    Rails.logger.warn "N+1 Query detected: #{event.payload[:message]}"
  end
end