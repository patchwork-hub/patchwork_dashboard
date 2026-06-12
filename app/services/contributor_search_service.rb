class ContributorSearchService
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::AssetTagHelper
  include ApplicationHelper

  SEARCH_REQUEST_TIMEOUT_SECONDS = 3
  SAVED_ACCOUNT_LOOKUP_ATTEMPTS = 3
  SAVED_ACCOUNT_LOOKUP_SLEEP_SECONDS = 1

  def initialize(query, options = {})
    @query = query
    @api_base_url = options[:url]
    @token = options[:token]
    @account_id = options[:account_id]
  end

  def call
    response = search_mastodon
    accounts = response.parsed_response['accounts']
    find_saved_accounts_with_retry(accounts)
  end

  private

  def search_mastodon
    HTTParty.get("#{@api_base_url}/api/v2/search",
      query: {
        q: @query,
        resolve: true,
        limit: 11
      },
      headers: {
        'Authorization' => "Bearer #{@token}"
      },
      timeout: SEARCH_REQUEST_TIMEOUT_SECONDS
    )
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError
    nil
  end

  def find_saved_accounts_with_retry(accounts)
    return [] unless accounts.present?

    saved_accounts = Account.none
    SAVED_ACCOUNT_LOOKUP_ATTEMPTS.times do |attempt|
      saved_accounts = Account.where(username: accounts.map { |account| account['username'] })
      break if saved_accounts.exists?

      sleep(SAVED_ACCOUNT_LOOKUP_SLEEP_SECONDS) if attempt < SAVED_ACCOUNT_LOOKUP_ATTEMPTS - 1
    end

    return [] unless saved_accounts.exists?

    saved_accounts.map do |account|

      {
        'id' => account.id.to_s,
        'username' => account.username,
        'display_name' => render_custom_emojis(account.display_name),
        'domain' => account.domain,
        'note' => account.note,
        'avatar_url' => account.avatar_url,
        'profile_url' => account.url,
        'following' => following_status(account),
        'is_muted' => is_muted(account),
        'is_own_account' => account.id == @account_id
      }
    end
  end

  def following_status(account)
    follow_ids = Follow.where(account_id: @account_id).pluck(:target_account_id)
    follow_request_ids = FollowRequest.where(account_id: @account_id).pluck(:target_account_id)

    if follow_ids.include?(account.id)
      'following'
    elsif follow_request_ids.include?(account.id)
      'requested'
    else
      'not_followed'
    end
  end

  def is_muted(account)
    Mute.where(account_id: @account_id, target_account_id: account.id).exists?
  end
end
