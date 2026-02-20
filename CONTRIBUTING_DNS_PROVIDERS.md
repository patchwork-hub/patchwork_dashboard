# Contributing DNS Providers

Thank you for your interest in adding DNS provider support! This guide will help you contribute a new DNS provider implementation.

## Current Status

- **Default Provider**: AWS Route53 (fully supported)
- **Community Providers**: We welcome contributions for additional DNS providers!

## How to Add a DNS Provider

### 1. Create Your Provider Class

Create a new file in `app/services/dns_providers/` named after your provider (e.g., `cloudflare_provider.rb`, `google_cloud_dns_provider.rb`, etc.).

Your provider must:
- Inherit from `DnsProviders::DnsProviderBase`
- Implement the `create_or_update_txt_record(domain, name, value)` method

**Template:**

```ruby
# app/services/dns_providers/your_provider.rb
class DnsProviders::YourProvider < DnsProviders::DnsProviderBase
  
  def initialize
    # Load your provider's credentials from environment variables
    @api_key = ENV['YOUR_PROVIDER_API_KEY']
    # Add any other initialization
  end

  # Creates or updates a TXT record
  # @param domain [String] The base domain (e.g., "example.com")
  # @param name [String] The full record name (e.g., "_atproto.subdomain.example.com")
  # @param value [String] The TXT record value (e.g., "did=did:plc:xyz123")
  # @return [Boolean] true if successful
  def create_or_update_txt_record(domain, name, value)
    # Your implementation here
    # Should create or update a TXT record with:
    # - Name: name parameter
    # - Type: TXT
    # - Value: value parameter
    # - TTL: 60 seconds (recommended)
    
    # Log success
    Rails.logger.info("Successfully created/updated TXT record: #{name} = #{value}")
    true
  rescue StandardError => e
    # Log errors
    Rails.logger.error("Failed to create DNS record: #{e.message}")
    raise e
  end
end
```

### 2. Document Required Environment Variables

Add a comment or section in your provider file listing required environment variables:

```ruby
# Required environment variables:
# - YOUR_PROVIDER_API_KEY: API key for authentication
# - YOUR_PROVIDER_ZONE_ID: Zone identifier (if applicable)
```

### 3. Test Your Implementation

Create a test to ensure your provider works correctly:

```ruby
# In Rails console
dns_provider = DnsProviders::YourProvider.new
result = dns_provider.create_or_update_txt_record(
  'example.com',
  '_atproto.test.example.com',
  'did=did:plc:test123'
)
puts result # Should be true
```

**That's it!** The factory automatically discovers your provider based on the filename.

### 4. Submit Your Pull Request

When submitting your PR, please include:

1. **Provider Implementation**: Your provider class file in `app/services/dns_providers/`
2. **Documentation**: Comments in your provider file explaining:
   - Required environment variables
   - Any provider-specific configuration
   - Example usage
3. **Testing**: Evidence that your provider works (screenshots, logs, etc.)

**That's all!** No need to modify the factory - it automatically discovers your provider.

## How Automatic Discovery Works

The `DnsProviderFactory` automatically:
1. Scans the `app/services/dns_providers/` directory
2. Finds all files matching `*_provider.rb` pattern
3. Loads the appropriate provider based on `DNS_PROVIDER` environment variable

**Naming Convention:**
- File: `cloudflare_provider.rb`
- Class: `DnsProviders::CloudflareProvider`
- ENV value: `DNS_PROVIDER=cloudflare`

## Supported DNS Providers

| Provider | Status | Maintainer |
|----------|--------|------------|
| AWS Route53 | ✅ Supported | Core Team |
| Cloudflare | 🔜 Contributions Welcome | - |
| Google Cloud DNS | 🔜 Contributions Welcome | - |
| Azure DNS | 🔜 Contributions Welcome | - |
| DigitalOcean DNS | 🔜 Contributions Welcome | - |
| Others | 🔜 Contributions Welcome | - |

# Bluesky Bridge Handle Configuration

This document explains how to configure Bluesky handle creation for your Mastodon instance.

## Configuration Options

### USE_LOCAL_DOMAIN

Controls whether to use local domain-based handles or Bridgy Fed default handles.

```bash
# In your .env file

# Use local domain (default)
USE_LOCAL_DOMAIN=true

# Use Bridgy Fed default handles
USE_LOCAL_DOMAIN=false
```

## Handle Formats

### When `USE_LOCAL_DOMAIN=true` (Default)

**DNS-based handles** - You manage your own DNS records for Bluesky verification.

#### For Communities/Channels:
- **Custom domain**: `customdomain.com`
- **Subdomain**: `channelname.yourdomain.com`

#### For Users:
- `username@yourdomain.com`

**Requirements:**
- DNS provider configured (Route53, Cloudflare, etc.)
- DNS records will be automatically created
- Full control over handle names

---

### When `USE_LOCAL_DOMAIN=false`

**Bridgy Fed handles** - Bridgy Fed manages DNS on your behalf.

#### For Communities/Channels:
- `channelname.yourdomain.com.ap.brid.gy`

#### For Users:
- `@username@yourdomain.com`

**Benefits:**
- No DNS configuration required
- No DNS provider needed
- Bridgy Fed handles all DNS resolution
- Simpler setup for testing

## Questions?

If you have questions about contributing a DNS provider, please:
1. Check the existing Route53 implementation for reference
2. Review the base class interface in `dns_providers/dns_provider_base.rb`
3. Open an issue for discussion before starting work

We appreciate your contributions! 🎉
