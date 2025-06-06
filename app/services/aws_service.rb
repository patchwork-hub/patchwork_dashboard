# frozen_string_literal: true

require 'aws-sdk-route53'

class AwsService
  def self.configure_aws
    Aws.config.update(
      region: ENV['AWS_DNS_REGION'],
      credentials: Aws::Credentials.new(
        ENV['AWS_ACCESS_DNS_RESOLVE_ID'],
        ENV['AWS_SECRET_DNS_RESOLVE_KEY']
      )
    )
  end
end