require 'httparty'

class ReblogPostService
  include HTTParty

  base_uri ENV['MASTODON_INSTANCE_URL']

  def initialize(token, status_id)
    @token = token
    @status_id = status_id
  end

  def call
    reblog_post
  end

  private

  # Reblog a status
  def reblog_post
    response = self.class.post(
      "/api/v1/statuses/#{@status_id}/reblog",
      headers: {
        "Authorization" => "Bearer #{@token}",
        "Content-Type"  => "application/json"
      },
      body: { visibility: 'public' }.to_json
    )

    {
      status: response.success? ? :ok : :error,
      body: response.parsed_response
    }
  rescue StandardError => e
    Rails.logger.error("ReblogPostService Error: #{e.message}")
    { status: :error, body: { error: e.message } }
  end
end
