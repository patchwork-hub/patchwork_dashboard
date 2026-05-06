class AccountDeletionService < BaseService
  def call(account)
    @account = account
    api_base_url = ENV['MASTODON_INSTANCE_URL']
    token = fetch_oauth_token
    delete_account(api_base_url, token)
  rescue HTTParty::Error => e
    Rails.logger.error("HTTP request failed: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("An unexpected error occurred: #{e.message}")
  end

  private

  def delete_account(api_base_url, token)
      payload = {
        id: @account.id
      }

      headers = {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json'
      }

      response = HTTParty.delete("#{api_base_url}/api/v1/patchwork/account_deletion",
                              body: payload.to_json,
                              headers: headers)

      unless response.code == 202 || response.code == 204 || response.code == 200
        Rails.logger.error("Failed to delete account: #{response.body}")
      end

      response
  end

  def fetch_oauth_token
    instance_owner = User.find_by(id: UserRole.where(role: 'owner').select(:user_id).first)
    return nil unless instance_owner

    token_service = GenerateAdminAccessTokenService.new(instance_owner.id)
    token_service.call
  end
end