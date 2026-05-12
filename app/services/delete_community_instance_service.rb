require 'httparty'

class DeleteCommunityInstanceService < BaseService
  LAMBDA_URL = ENV.fetch('DELETE_COMMUNITY_LAMBDA_URL', nil)
  LAMBDA_API_KEY = ENV.fetch('DELETE_COMMUNITY_LAMBDA_API_KEY', nil)

  def call(community)
    return false if LAMBDA_URL.nil? || LAMBDA_API_KEY.nil?

    return false if community.ip_address_id.nil?

    ip_address = IpAddress.find(community.ip_address_id)
    return false if ip_address.nil?

    ip = ip_address&.private_ip

    @payload = {
      client: "#{community.id}_#{community.slug}",
      ip_address: ip,
    }.to_json
    response = invoke_lambda
    if response.success?
      ip_address.decrement_use_count
      true
    else
      log_failed_response(response)
      false
    end
  rescue => e
    Rails.logger.error "[DeleteCommunityInstanceService] Error calling lambda: #{e.message}"
    Rails.logger.error "[DeleteCommunityInstanceService] Backtrace: #{e.backtrace.join("\n")}"
    false
  end

  private

  def invoke_lambda
    HTTParty.post(
      LAMBDA_URL,
      body: @payload,
      headers: {
        'Content-Type' => 'application/json',
        'x-api-key' => LAMBDA_API_KEY,
      }
    )
  end

  def log_failed_response(response)
    Rails.logger.error "[DeleteCommunityInstanceService] Lambda call failed with status: #{response.code}"
    Rails.logger.error "[DeleteCommunityInstanceService] Response body: #{response.body}"
  end
end
