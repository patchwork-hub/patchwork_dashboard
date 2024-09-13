class LoginService < BaseService
  def initialize(account, password)
    @account = account
    @password = password
  end

  def call
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    payload = {
      grant_type: 'password',
      username: @account.email,
      password: @password,
      client_id: ENV['MASTODON_CLIENT_ID'],
      client_secret: ENV['MASTODON_CLIENT_SECRET'],
      redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
      scope: 'read write follow'
    }

    begin
      response = HTTParty.post("#{api_base_url}/oauth/token", body: payload)
      
      if response.success?
        response.parsed_response['access_token']
      else
        puts "Error: Failed to obtain OAuth token: #{response.message}"
        nil
      end
    rescue Errno::ECONNREFUSED => e
      puts "Connection refused: #{e.message}"
      nil
    rescue SocketError => e
      puts "Socket error: #{e.message}"
      nil
    rescue HTTParty::Error => e
      puts "HTTP request failed: #{e.message}"
      nil
    rescue StandardError => e
      puts "An unexpected error occurred: #{e.message}"
      nil
    end
  end
end
