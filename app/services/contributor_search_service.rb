class ContributorSearchService
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::AssetTagHelper
  include ApplicationHelper

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
      }
    )
  end

  def find_saved_accounts_with_retry(accounts)
    return [] unless accounts.present?

    saved_accounts = []
    while saved_accounts.empty?
      saved_accounts = Account.where(username: accounts.map { |account| account['username'] })
      sleep(2) if saved_accounts.empty?
    end

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
