# frozen_string_literal: true

module Api
  module V1
    class WaitListController < ApiController
      skip_before_action :verify_key!
      
      def create
        wait_list = WaitList.new
        wait_list.generate_invitation_code
        wait_list.channel_type = params[:channel_type]
        
        if wait_list.save
          render_created(wait_list, 'api.wait_list.messages.created')
        else
          render_validation_failed(wait_list.errors, 'api.wait_list.errors.validation_failed')
        end
      end

      def request_invitation_code
        email = params[:email]
        
        if email.blank?
          render_errors('api.wait_list.errors.email_required', :bad_request)
          return
        end
        
        wait_list = WaitList.find_or_create_by(email: email, used: false) do |wl|
          wl.description = params[:description]
          wl.generate_invitation_code
        end
        
        if wait_list.persisted?
          WaitListMailer.with(email: email, invitation_code: wait_list.invitation_code).send_invitation_code.deliver_later
          render_success({}, 'api.wait_list.messages.invitation_sent')
        else
          render_validation_failed(wait_list.errors, 'api.wait_list.errors.validation_failed')
        end
      end

      def validate_code
        invitation_code = params[:invitation_code]
        
        if invitation_code.blank?
          render_errors('api.wait_list.errors.invitation_code_required', :bad_request)
          return
        end
        
        wait_list = WaitList.find_by(invitation_code: invitation_code.to_s, used: false)
        
        if wait_list
          render_success(wait_list, 'api.wait_list.messages.code_valid')
        else
          render_errors('api.wait_list.errors.invalid_code', :unprocessable_entity)
        end
      end

    end
  end
end
