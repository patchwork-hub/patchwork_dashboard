# frozen_string_literal: true

module Api
  module V1
    class SessionsController < ApiController
      include Devise::Controllers::Helpers

      skip_before_action :verify_key!, only: [:log_out]
      before_action :authenticate_user_from_header, only: [:log_out]

      def log_out
        if current_user
          token = bearer_token
          revoke_access_token(token)
          sign_out(current_user)
        end
        cookies.delete(:access_token, domain: :all)        
        render json: { message: 'Success!' }, status: 200
      end

      private

      def revoke_access_token(token)
        return nil unless token

        begin
          url = Rails.env.development? ? 'http://localhost:3000/oauth/revoke' : 'https://channel.org/oauth/revoke'

          HTTParty.post(
            url,
            body: {
              token: token,
              client_id: "7Xn_TbJq9D5uWhT_sL9Te9yXAJ26UrxSlXtBoKT7rt0",
              client_secret: "5yf68rGhPsxPuSQd2RMHZ8tHV02GPIYOV5fT88V07o8"
            },
            headers: { 'Authorization': "Bearer #{token}" }
          )
        rescue HTTParty::Error => e
          Rails.logger.error "Failed to revoke access token: #{e.message}"
        end
      end

      def bearer_token
        pattern = /^Bearer /
        header  = request.headers['Authorization']
        header.gsub(pattern, '') if header && header.match(pattern)
      end

    end
  end
end