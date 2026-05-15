# frozen_string_literal: true

module ServerSettingConfig
  extend ActiveSupport::Concern

  CONFIG_PATH = Rails.root.join("config", "server_settings.yml").freeze

  # ============================================================================
  # Stable key constants — use these everywhere instead of hardcoded name strings.
  # These MUST match the keys in config/server_settings.yml.
  # ============================================================================

  # Parent groups
  KEY_SPAM_BLOCK         = "spam_block"
  KEY_CONTENT_MODERATION = "content_moderation"
  KEY_FEDERATION         = "federation"
  KEY_LOCAL_FEATURES     = "local_features"
  KEY_USER_MANAGEMENT    = "user_management"
  KEY_PLUGINS            = "plugins"
  KEY_BLUESKY_BRIDGE     = "bluesky_bridge"
  KEY_EMAIL_BRANDING     = "email_branding"

  # Child settings
  KEY_SPAM_FILTERS       = "spam_filters"
  KEY_SIGNUP_CHALLENGE   = "signup_challenge"
  KEY_CONTENT_FILTERS    = "content_filters"
  KEY_BLUESKY            = "bluesky"
  KEY_THREADS            = "threads"
  KEY_LIVE_BLOCKLIST     = "live_blocklist"
  KEY_CUSTOM_THEME       = "custom_theme"
  KEY_SEARCH_OPT_OUT     = "search_opt_out"
  KEY_LOCAL_ONLY_POSTS   = "local_only_posts"
  KEY_LONG_POSTS         = "long_posts"
  KEY_LOCAL_QUOTE_POSTS  = "local_quote_posts"
  KEY_GUEST_ACCOUNTS     = "guest_accounts"
  KEY_NEWSLETTERS        = "newsletters"
  KEY_ANALYTICS          = "analytics"
  KEY_BLUESKY_BRIDGE_AUTO = "bluesky_bridge_auto"

  included do
    scope :by_key, ->(key) { find_by(key: key) }
  end

  class_methods do
    def config
      @config ||= YAML.load_file(CONFIG_PATH)
    end

    def reload_config!
      @config = nil
    end

    def display_name_for(key)
      config.dig(key, "name") || key.to_s.humanize
    end

    def description_for(key)
      config.dig(key, "description") || ""
    end

    def tooltip_for(key)
      config.dig(key, "tooltip") || ""
    end
  end

  # Instance methods — delegate to class methods using this record's key
  def display_name
    key.present? ? self.class.display_name_for(key) : name
  end

  def setting_description
    key.present? ? self.class.description_for(key) : ""
  end

  def tooltip
    key.present? ? self.class.tooltip_for(key) : ""
  end
end
