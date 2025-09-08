# frozen_string_literal: true

module Api
  module V1
    class SettingsController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_and_set_account
      before_action :validate_or_set_app_name
      before_action :set_setting, only: [:destroy]

      def index
        @setting = Setting.find_by(account: @account, app_name: @app_name)

        if @setting
          render_success(@setting)
        else
          render_success(default_setting)
        end
      end

      def upsert
        @setting = Setting.find_or_initialize_by(account: @account, app_name: @app_name)

        if @setting.update(setting_params)
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
        if request.headers['Authorization'].present? && params[:instance_domain].present?
          validate_mastodon_account
          @account = current_remote_account
        else
          authenticate_user_from_header
          @account = current_account
        end
      rescue AuthenticationError
        render_unauthorized('api.setting.errors.authentication_failed')
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
        params.permit(settings: [theme: [:type]])
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
    end
  end
end
