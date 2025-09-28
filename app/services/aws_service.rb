# frozen_string_literal: true

require 'aws-sdk-route53'

class AwsService
  def self.configure_aws
    # No longer set global AWS config - let Paperclip use its own S3 credentials
    # Route53 clients will use their own credentials separately
  end

  def self.route53_client
    Aws::Route53::Client.new(
      region: ENV['AWS_DNS_REGION'],
      credentials: Aws::Credentials.new(
        ENV['AWS_ACCESS_DNS_RESOLVE_ID'],
        ENV['AWS_SECRET_DNS_RESOLVE_KEY']
      )
    )
  end
end