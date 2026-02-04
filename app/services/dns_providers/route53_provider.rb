# AWS Route53 DNS provider implementation
class DnsProviders::Route53Provider < DnsProviders::DnsProviderBase
  # Require AWS service for Route53 client
  require_relative '../aws_service'

  # Creates or updates a TXT record in AWS Route53
  #
  # @param domain [String] The base domain (e.g., "example.com")
  # @param name [String] The full record name (e.g., "_atproto.subdomain.example.com")
  # @param value [String] The TXT record value (e.g., "did=did:plc:xyz123")
  def create_or_update_txt_record(domain, name, value)
    route53 = AwsService.route53_client
    hosted_zones = route53.list_hosted_zones
    
    # Find the hosted zone for the domain
    # AWS Route53 requires trailing dot in zone names
    zone_name = "#{domain}."
    hosted_zone = hosted_zones.hosted_zones.find { |zone| zone.name == zone_name }

    unless hosted_zone
      Rails.logger.error("Hosted zone for #{domain} not found in Route53.")
      return false
    end

    # Format the TXT record value with proper quoting
    formatted_value = "\"#{value}\""

    # Create or update the TXT record using UPSERT action
    route53.change_resource_record_sets({
      hosted_zone_id: hosted_zone.id,
      change_batch: {
        changes: [
          {
            action: 'UPSERT',
            resource_record_set: {
              name: name,
              type: 'TXT',
              ttl: 60,
              resource_records: [
                { value: formatted_value },
              ],
            },
          },
        ],
      },
    })

    Rails.logger.info("Successfully created/updated TXT record: #{name} = #{formatted_value}")
    true
  rescue StandardError => e
    Rails.logger.error("Failed to create DNS record via Route53: #{e.message}")
    raise e
  end
end
