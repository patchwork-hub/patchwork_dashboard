require 'httparty'

class CreateCommunityInstanceDataJob < ApplicationJob
  queue_as :default

  LAMBDA_URL = ENV['CREATE_CHANNEL_LAMBDA_URL']
  LAMBDA_API_KEY = ENV['CREATE_CHANNEL_LAMBDA_API_KEY']

  def perform(community_id, community_slug)
    domain = generate_domain(community_slug)
    admins = prepare_admins(community_id)
    payload = build_payload(community_id, community_slug, domain, admins)

    response = invoke_lambda(payload)

    handle_response(response)
  end

  private

  def generate_domain(community_slug)
    "#{community_slug}.channel.org"
  end

  def prepare_admins(community_id)
    Account.joins(:community_admins)
           .where(community_admins: { patchwork_community_id: community_id })
           .map { |account| "@#{account.username}@channel.org" }
           .join(', ')
  end

  def build_payload(community_id, community_slug, domain, admins)
    {
      id: community_id,
      client: "#{community_id}_#{community_slug}",
      web: calculate_web_port(community_id),
      sidekiq: calculate_sidekiq_port(community_id),
      upstream_web: "#{community_id}_#{community_slug}_web",
      upstream_stream: "#{community_id}_#{community_slug}_stream",
      REDIS_NAMESPACE: community_slug,
      WEB_DOMAIN: domain,
      STREAMING_API_BASE_URL: "wss://#{domain}",
      LOCAL_DOMAIN: domain,
      WORKPLACE_DB_DATABASE: community_slug,
      AWS_ACCESS_KEY_ID: ENV['AWS_ACCESS_KEY_ID'],
      AWS_SECRET_ACCESS_KEY: ENV['AWS_SECRET_ACCESS_KEY'],
      ADMINS: admins
    }.to_json
  end

  def calculate_web_port(community_id)
    ENV['WEB_PORT'].to_i + community_id.to_i
  end

  def calculate_sidekiq_port(community_id)
    ENV['SIDEKIQ_PORT'].to_i + community_id.to_i
  end

  def invoke_lambda(payload)
    response = HTTParty.post(
      LAMBDA_URL,
      body: payload,
      headers: {
        'Content-Type' => 'application/json',
        'x-api-key' => LAMBDA_API_KEY
      }
    )

    response
  end

  def handle_response(response)
    Rails.logger.info("Lambda invocation response: #{response.body}")
    if response.success?
      Rails.logger.info("Lambda function triggered successfully: #{response.body}")
    else
      Rails.logger.error("Lambda invocation failed: #{response.code} #{response.message}, Body: #{response.body}")
    end
  end
end
