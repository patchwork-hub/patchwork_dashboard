# frozen_string_literal: true

require 'httparty'

class PostStatusService < BaseService
  def call(token: nil, options: {})
    @token = token
    @params = options
    @api_base_url = ENV['MASTODON_INSTANCE_URL']
    create_status
  end

  def create_status

    headers = {
      'Authorization' => "Bearer #{@token}",
      'Content-Type' => 'application/json'
    }


    response = HTTParty.post("#{@api_base_url}/api/v1/statuses",
                             body: @params.to_json,
                             headers: headers)

    unless response.code == 200
      Rails.logger.error("Failed to create status: #{response.body}")
    end

    response
  end
end
