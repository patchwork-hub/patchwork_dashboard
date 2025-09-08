# config/initializers/mastodon_emojis.rb

require 'net/http'
require 'json'

module MastodonEmoji
  INSTANCE_URL = ENV.fetch("MASTODON_INSTANCE_URL", "https://channel.org")
  CACHE_KEY = "mastodon_custom_emojis"
  CACHE_EXPIRY = 6.hours

  def self.fetch_and_cache_emojis
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_EXPIRY) do
      url = URI("#{INSTANCE_URL}/api/v1/custom_emojis")
      response = Net::HTTP.get(url)
      JSON.parse(response).each_with_object({}) do |emoji, hash|
        shortcode = ":#{emoji['shortcode']}:"
        hash[shortcode] = emoji['url']
      end
    rescue => e
      Rails.logger.error("Failed to fetch Mastodon emojis: #{e.message}")
      {}
    end
  end
end
