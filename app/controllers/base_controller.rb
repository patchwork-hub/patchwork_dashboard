class BaseController < ApplicationController
  def index
    @records = load_records
    @search = records_filter.build_search
  end

  def load_records
    records_filter.get
  end

  def records_filter
    raise NotImplementedError, "Subclasses must implement the `records_filter`."
  end

  def set_api_credentials
    @api_base_url = ENV['MASTODON_INSTANCE_URL']
    admin = Account.where(id: get_community_admin_id).first
    if admin
      @token = fetch_oauth_token(admin.user.id)
    end
  end

  def get_community_admin_id
    CommunityAdmin.where(patchwork_community_id: @community.id, is_boost_bot: true).pluck(:account_id).first
  end

  def fetch_oauth_token(user_id)
    token_service = GenerateAdminAccessTokenService.new(user_id)
    token_service.call
  end
end
