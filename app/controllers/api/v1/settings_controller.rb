# frozen_string_literal: true

module Api
  module V1
    class SettingsController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_and_set_account
      before_action :validate_or_set_app_name
      before_action :set_setting, only: [:destroy]

      def index
        @setting = with_timing('settings.index.find_by') do
          Setting.find_by(account: @account, app_name: @app_name)
        end

        if @setting
          render_success(@setting)
        else
          render_success(default_setting)
        end
      end

      def upsert
        @setting = Setting.find_or_initialize_by(account: @account, app_name: @app_name)
        current_settings = (@setting.settings || {}).with_indifferent_access
        incoming = setting_params[:settings] || {}

        updates = {}
        updates[:theme] = { type: incoming.dig(:theme, :type) } if incoming.dig(:theme, :type).present?
        updates[:layout] = { tab_order: incoming.dig(:layout, :tab_order) } if incoming.dig(:layout, :tab_order).present?
        updates[:user_timeline] = incoming[:user_timeline] if incoming.key?(:user_timeline)

        # Use deep_merge! to combine the updates into the current settings
        current_settings.deep_merge!(updates)

        if @setting.update(settings: current_settings)
          render_success(@setting, 'api.setting.messages.saved')
        else
          render_validation_failed(@setting.errors, 'api.setting.errors.validation_failed')
        end
      end

      def destroy
        if @setting.destroy
          render_deleted('api.setting.messages.deleted')
        else
          render_errors('api.setting.errors.delete_failed', :unprocessable_entity)
        end
      end

      private

      def set_setting
        @setting = Setting.find_by(account: @account, app_name: @app_name)
        render_not_found('api.setting.errors.not_found') unless @setting
      end

      def authenticate_and_set_account
        auth_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        if request.headers['Authorization'].present? && params[:instance_domain].present?
          with_timing('settings.index.validate_mastodon_account') { validate_mastodon_account }
          @account = with_timing('settings.index.current_remote_account') { current_remote_account }
        else
          with_timing('settings.index.authenticate_user_from_header') { authenticate_user_from_header }
          @account = with_timing('settings.index.current_account') { current_account }
        end
      rescue AuthenticationError
        render_unauthorized('api.setting.errors.authentication_failed')
      ensure
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - auth_started_at) * 1000).round(1)
        Rails.logger.info("[settings#index] authenticate_and_set_account=#{elapsed_ms}ms")
      end

      def validate_or_set_app_name
        app_name_param = params[:app_name]
        if app_name_param.blank?
          @app_name = Setting.column_defaults['app_name']
        elsif Setting.app_names.key?(app_name_param)
          @app_name = app_name_param
        else
          render_errors('api.setting.errors.invalid_app_name', :bad_request, {
            valid_options: Setting.app_names.keys,
            attribute: app_name_param
          })
        end
      end

      def setting_params
        params.permit(
          settings: [
            theme: [:type],
            layout: [:tab_order],
            user_timeline: []
          ]
        )
      end

      def default_setting
        {
          app_name: @app_name,
          account_id: @account.id,
          settings: {
            theme: {
              type: setting_params.present? ? setting_params[:settings][:theme][:type] || nil : nil
            }
          }
        }.compact
      end

      def with_timing(label)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
        Rails.logger.info("[settings#index] #{label}=#{elapsed_ms}ms")
        result
      end
    end
  end
end
