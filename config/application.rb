require_relative "boot"

require "rails/all"

require 'csv'

require 'doorkeeper'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dashboard
  class Application < Rails::Application
    config.app_generators.scaffold_controller :responders_controller

    config.load_defaults 7.0

    config.time_zone = "London"

    #config.action_mailer.deliver_later_queue_name = 'mailers'

    # smtp settings
    config.action_mailer.smtp_settings = {
      address:                  ENV["SMTP_SERVER"],
      port:                     ENV["SMTP_PORT"],
      user_name:                ENV["SMTP_LOGIN"],
      password:                 ENV["SMTP_PASSWORD"],
      domain:                   ENV['SMTP_DOMAIN'],
      authentication:           "login",
      enable_starttls_auto:     true
    }

    # Sidekiq/redis job runner
    config.active_job.queue_adapter = :sidekiq
    config.active_job.queue_name_prefix = "dashboard_#{Rails.env}"
  end
end
