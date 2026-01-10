require 'httparty'

class CreateCommunityInstanceDataJob < ApplicationJob
  queue_as :default

  LAMBDA_URL = ENV['CREATE_CHANNEL_LAMBDA_URL']
  LAMBDA_API_KEY = ENV['CREATE_CHANNEL_LAMBDA_API_KEY']

  def perform(community)
    community_id = community.id
    community_slug = community.slug
    @is_custom_domain = community.is_custom_domain

    if @is_custom_domain
      @domain = community_slug
      community_slug = community_slug.parameterize.underscore
    else
      @domain = generate_domain(community_slug)
    end

    @admins = prepare_admins(community_id)
    @display_name = community.name
    @rules = prepare_rules(community)
    @additional_information = prepare_additional_information(community)
    @links = prepare_links(community)
    @header_image = community.banner_image.url
    @logo_image = community.logo_image.url
    @contact_email = CommunityAdmin.where(patchwork_community_id: community_id, account_status: 0).pluck(:email).first
    @channel_type = get_channel_type(community)
    @single_user_mode = (community.hub? && community.registration_mode == 'none').to_s
    @registration_mode = community.registration_mode
    @ip_address = community.ip_address&.private_ip

    payload = build_payload(community_id, community_slug)
    puts payload

    response = invoke_lambda(payload)

    handle_response(response)
  end

  private

  def generate_domain(community_slug)
    "#{community_slug}.channel.org"
  end

  def prepare_admins(community_id)
    admins = CommunityAdmin.where(patchwork_community_id: community_id, account_status: 0)
                .select(:display_name, :email, :username, :password, :id)

    admins.each_with_object({}) do |admin, hash|
      hash[admin.id] = {
        'display_name' => admin.display_name,
        'email' => admin.email,
        'username' => admin.username,
        'password' => admin.password
      }
    end
  end

  def prepare_rules(community)
    CommunityRule.where(patchwork_community_id: community.id).each_with_object({}) do |rule, hash|
      hash[rule.id] = rule.rule
    end
  end

  def prepare_additional_information(community)
    community.patchwork_community_additional_informations.each_with_object({}) do |info, hash|
      hash[info.id] = { 'heading' => info.heading, 'text' => info.text }
    end
  end

  def prepare_links(community)
    community.patchwork_community_links.each_with_object({}) do |link, hash|
      hash[link.id] = { 'icon' => link.icon, 'name' => link.name, 'url' => link.url }
    end
  end

  def get_channel_type(community)
    content_type = community.content_type
    # instead of nil, want to get ""
    content_type&.channel_type || ""
  end

  def build_payload(community_id, community_slug)
    {
      id: community_id,
      client: "#{community_id}_#{community_slug}",
      web: calculate_web_port(community_id),
      sidekiq: calculate_sidekiq_port(community_id),
      upstream_web: "#{community_id}_#{community_slug}_web",
      upstream_stream: "#{community_id}_#{community_slug}_stream",
      WEB_DOMAIN: @domain,
      STREAMING_API_BASE_URL: "wss://#{@domain}",
      LOCAL_DOMAIN: @domain,
      WORKPLACE_DB_DATABASE: community_slug,
      AWS_ACCESS_KEY_ID: ENV['AWS_ACCESS_KEY_ID'],
      AWS_SECRET_ACCESS_KEY: ENV['AWS_SECRET_ACCESS_KEY'],
      ADMINS: @admins,
      RULES: @rules,
      INFORMATION: @additional_information,
      LINKS: @links,
      HEADER_IMAGE: @header_image,
      LOGO_IMAGE: @logo_image,
      SITE_CONTACT_EMAIL: @contact_email,
      DISPLAY_NAME: @display_name,
      MAIN_CHANNEL: "false",
      CHANNEL_TYPE: @channel_type,
      IS_CUSTOM_DOMAIN: @is_custom_domain,
      REGISTRATION_MODE: @registration_mode,
      SINGLE_USER_MODE: @single_user_mode,
      IP_ADDRESS: @ip_address,
      SMS_REGION: ENV['SMS_REGION'],
      SMTP_LOGIN: ENV['SMTP_LOGIN'],
      SMTP_PASSWORD: ENV['SMTP_PASSWORD'],
      SMTP_SERVER: ENV['SMTP_SERVER'],
      SMTP_FROM_ADDRESS: ENV['SMTP_FROM_ADDRESS'],
      SMTP_DOMAIN: ENV['SMTP_DOMAIN'],
      SMTP_AUTH_METHOD: ENV['SMTP_AUTH_METHOD'],
      SMTP_ENABLE_STARTTLS: ENV['SMTP_ENABLE_STARTTLS'],
      SMTP_ENABLE_STARTTLS_AUTO: ENV['SMTP_ENABLE_STARTTLS_AUTO'],
      SMTP_PORT: ENV['SMTP_PORT']
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
