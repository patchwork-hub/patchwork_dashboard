module Api
  module V1
    class DomainsController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_user_from_header

      def verify
        domain = params[:domain]
        expected_ip = params[:ipAddress]

        if domain.blank? || expected_ip.blank?
          return render_errors('api.domain.errors.missing_parameters', :bad_request)
        end

        verified = DnsVerifier.valid_a_record?(domain, expected_ip)
        
        if verified
          render_domain_message_key('api.domain.messages.dns_verified', verified)
        else
          render_domain_message_key('api.domain.messages.dns_instructions',
            { verified: verified,
              attribute: expected_ip 
            }
          )
        end
      rescue StandardError => e
        Rails.logger.error "DNS verification failed: #{e.message}"
        render_errors('api.domain.errors.verification_failed', :unprocessable_entity)
      end
    end
  end
end
