# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApiController
      skip_before_action :verify_key!
			before_action :check_authorization_header
      before_action :set_authenticated_account

      def update_bluesky_bridge_setting
        return render_not_found unless @account

        desired_value = parse_boolean_param(user_params[:bluesky_bridge_enabled])
        user = @account.user

        # Validate parameter presence first
        if desired_value.nil?
          return render_error('api.errors.invalid_request', :bad_request)
        end

        # Check if user meets the requirements for Bluesky Bridge
        error_message = meets_bluesky_bridge_requirements
        if error_message.present?
          return render_errors(error_message, :unprocessable_entity)
        end

        if user.update_column(:bluesky_bridge_enabled, desired_value)
        render_success({id: user.id, bluesky_bridge_enabled: user.bluesky_bridge_enabled}, 'api.messages.updated')
        else
          render_validation_failed(user.errors, 'api.errors.validation_failed')
        end
      end

      def index
        return render_not_found unless @account

        user = @account.user

        render_success({ id: user.id, bluesky_bridge_enabled: user.bluesky_bridge_enabled })
      end

    private

      def parse_boolean_param(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def meets_bluesky_bridge_requirements
        missing_fields = []
        missing_fields << 'Username' unless @account&.username.present?
        missing_fields << 'Display name' unless @account&.display_name.present?
        missing_fields << 'Avatar' unless @account&.avatar.present?
        missing_fields << 'Header' unless @account&.header.present?

        return nil if missing_fields.empty?
        if missing_fields.size == 1
          "User does not meet Bluesky Bridge requirements. #{missing_fields.first} is required."
        else
          "User does not meet Bluesky Bridge requirements. #{missing_fields.join(', ')} are required."
        end
      end

      def set_authenticated_account
        if params[:instance_domain].present?
          @account = current_remote_account
        else
          @account = current_account
        end

        return render_unauthorized unless @account

        @account
      end

      def user_params
        params.permit(:bluesky_bridge_enabled)
      end
    end
  end
end
