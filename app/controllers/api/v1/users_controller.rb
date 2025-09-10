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

        # Validate parameter presence first
        if desired_value.nil?
          return render_error('api.errors.invalid_request', :bad_request)
        end

        # Check if user meets the requirements for Bluesky Bridge
        unless meets_bluesky_bridge_requirements?
          return render_errors('api.account.errors.unable_to_bridge', :unprocessable_entity)
        end

        if current_user.update(bluesky_bridge_enabled: desired_value)
          render_success({id: current_user.id, bluesky_bridge_enabled: current_user.bluesky_bridge_enabled}, 'api.messages.updated')
        else
          render_validation_failed(current_user.errors, 'api.errors.validation_failed')
        end
      end

    private

      def parse_boolean_param(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def meets_bluesky_bridge_requirements?
        @account&.username.present? && @account&.display_name.present? && 
        @account&.avatar.present? && @account&.header.present?
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