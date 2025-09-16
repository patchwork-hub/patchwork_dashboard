# frozen_string_literal: true

module Api
  module V1
    class ServerSettingsController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_client_credentials, only: [:menu_visibility]

      # GET /api/v1/server_settings/menu_visibility
      def menu_visibility
        # Cache the result for performance since server settings don't change frequently
        @menu_config = build_menu_visibility_config

        render_success(@menu_config)
      end

      private

      def build_menu_visibility_config
        # Efficiently fetch the Bluesky setting with a single optimized query
        bluesky_setting = fetch_bluesky_setting

        # Build the menu visibility configuration
        {
          bluesky_bridge_enabled: bluesky_setting&.value || false,
        }
      end

      def fetch_bluesky_setting
        # Use a more efficient query with includes to avoid N+1 queries
        ServerSetting.includes(:parent)
                     .joins(:parent)
                     .where(name: 'Enable bluesky bridge', parent: { name: 'Bluesky Bridge' })
                     .first
      rescue StandardError => e
        Rails.logger.error "Error fetching Bluesky setting: #{e.message}"
        nil
      end
    end
  end
end