class AccountsController < BaseController
  before_action :find_account, only: [:follow, :unfollow]

  def show; end

  def follow
    community = Community.find(params[:community_id])
    community_admin = community.community_admins&.first.account
    follow = FollowService.new.call(community_admin, @account)
    render json: { message: 'successfully_followed' }, status: :ok
  end

  def unfollow
    community = Community.find(params[:community_id])
    community_admin = community.community_admins&.first.account
    unfollow = UnfollowService.new.call(community_admin, @account)
    render json: { message: 'successfully_unfollowed' }, status: :ok
  end

  def find_account
    @account = Account.find(params[:id])
  end

  def records_filter
    @filter = Filter::Account.new(params)
  end
end
