class AccountsController < BaseController
  before_action :find_account, only: [:follow, :unfollow]
  before_action :find_admin, only: [:follow, :unfollow]

  def show; end

  def follow
    FollowService.new.call(@admin, @account)
    render json: { message: 'successfully_followed' }, status: :ok
  end

  def unfollow
    UnfollowService.new.call(@admin, @account)
    render json: { message: 'successfully_unfollowed' }, status: :ok
  end

  def export
    accounts = records_filter.public_scope.joins(:user).includes(:user).where.not(users: { confirmed_at: nil })

    domain = ENV['LOCAL_DOMAIN'] || 'example.com'

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Username', 'Display name', 'Email address', 'Time and date account opened']
      accounts.find_each do |account|
        csv << [
          "@#{account.username}@#{domain}",
          account.display_name,
          account.user&.email || '-',
          account.created_at.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end

    send_data csv_data, filename: "registered_users_#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}.csv", type: 'text/csv'
  end

  def find_account
    @account = Account.find(params[:id])
  end

  def find_admin
    community = Community.find(params[:community_id])
    @admin = Account.find_by(id: CommunityAdmin.where(patchwork_community_id: community.id, is_boost_bot: true, account_status: 0).pluck(:account_id).first)
  end

  def records_filter
    @filter = Filter::Account.new(params)
  end
end
