require_relative "boot"

require "rails/all"

require 'csv'

require 'doorkeeper'

require_relative '../lib/middleware/bullet_logger'
require_relative '../lib/middleware/query_profiler'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dashboard
  class Application < Rails::Application
    config.app_generators.scaffold_controller :responders_controller

    config.load_defaults 7.0

    config.time_zone = "London"

    # I18n configuration for internationalization
    # Set default locale to English and add available locales
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :de, :ja, :ru, :cy, :fr, :it, :pt_BR, :pt]
    # Set English as fallback locale for missing translations
    config.i18n.fallbacks = { 
      de: :en, ja: :en, ru: :en, cy: :en, fr: :en, it: :en, pt_BR: :en, pt: :en 
    }
    # Load all locale files from subdirectories
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]

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

    #  N+1 query logging for Postman and SQL profiling in API responses
    # config.middleware.insert_after ActionDispatch::Executor, BulletLogger
    # config.middleware.insert_before 0, QueryProfiler

  end
end
