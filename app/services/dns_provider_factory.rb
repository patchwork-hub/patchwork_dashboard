# Factory class for creating DNS provider instances
# Automatically discovers and loads DNS providers from the dns_providers directory
class DnsProviderFactory
  PROVIDERS_PATH = File.join(__dir__, 'dns_providers')
  
  # Returns a DNS provider instance based on configuration
  # Automatically discovers available providers from dns_providers directory
  #
  # @return [DnsProviders::DnsProviderBase] An instance of the configured DNS provider
  # @raise [ArgumentError] If the configured provider is not found
  def self.create
    provider_name = ENV.fetch('DNS_PROVIDER', 'route53').downcase
    
    # Normalize provider name (remove special characters, convert to snake_case)
    normalized_name = normalize_provider_name(provider_name)
    
    provider_class = load_provider_class(normalized_name)
    
    if provider_class
      provider_class.new
    else
      available = supported_providers.join(', ')
      raise ArgumentError, "DNS provider '#{provider_name}' not found. Available providers: #{available}"
    end
  end

  # Returns a list of all available DNS provider names by scanning the dns_providers directory
  #
  # @return [Array<String>] List of available provider names
  def self.supported_providers
    return @supported_providers if @supported_providers
    
    @supported_providers = []
    
    # Scan the dns_providers directory for provider files
    Dir.glob(File.join(PROVIDERS_PATH, '*_provider.rb')).each do |file|
      # Extract provider name from filename (e.g., "route53_provider.rb" -> "route53")
      provider_name = File.basename(file, '.rb').sub(/_provider$/, '')
      @supported_providers << provider_name unless provider_name == 'dns_provider_base'
    end
    
    @supported_providers.sort
  end
  
  # Clears the cached list of supported providers (useful for testing)
  def self.reload_providers!
    @supported_providers = nil
  end

  private

  # Normalizes provider name to match file naming convention
  # Examples: 'route53' -> 'route53', 'google-cloud-dns' -> 'google_cloud_dns'
  def self.normalize_provider_name(name)
    case name
    when 'aws'
      'route53'
    when 'google', 'gcp', 'google-cloud-dns'
      'google_cloud_dns'
    else
      name.tr('-', '_')
    end
  end

  # Attempts to load and return the provider class
  # @param provider_name [String] Normalized provider name
  # @return [Class, nil] The provider class or nil if not found
  def self.load_provider_class(provider_name)
    # Build the expected class name (e.g., "route53" -> "Route53Provider")
    class_name = provider_name.split('_').map(&:capitalize).join + 'Provider'
    
    # Build the expected file path
    file_path = File.join(PROVIDERS_PATH, "#{provider_name}_provider.rb")
    
    # Check if the file exists
    return nil unless File.exist?(file_path)
    
    # Require the file
    require_relative "dns_providers/#{provider_name}_provider"
    
    # Return the class constant
    DnsProviders.const_get(class_name)
  rescue NameError => e
    Rails.logger.error("Failed to load DNS provider class for '#{provider_name}': #{e.message}")
    nil
  end
end
