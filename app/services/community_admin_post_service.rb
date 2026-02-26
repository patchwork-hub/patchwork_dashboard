class CommunityAdminPostService < BaseService
  def initialize(community_admin, current_user, community)
    @community_admin = community_admin
    @current_user = current_user
    @community = community
  end

  def call
    create_admin!
  end

  private

  def create_admin!
    is_locked = @community&.content_type&.group_channel? ? true : false
    account_attributes = {
      display_name: @community_admin.display_name,
      avatar: @community.avatar_image || '',
      header: @community.banner_image || '',
      note: @community.description,
      discoverable: true,
      locked: is_locked
    }

    if @community_admin.is_boost_bot
      account_attributes[:actor_type] = 'Service'
    else
      account_attributes[:actor_type] = 'Person'
    end

    admin = Account.find_or_initialize_by(username: @community_admin.username, domain: nil)
    admin.assign_attributes(account_attributes.compact)
    admin.save!

    @community_admin.update(account_id: admin.id)

    user_attributes = {
      email: @community_admin.email,
      confirmed_at: Time.now.utc,
      role: UserRole.find_by(name: @community_admin.role),
      agreement: true,
      approved: true
    }

    unless @current_user.user_admin?
      user_attributes[:password] = @community_admin.password
      user_attributes[:password_confirmation] = @community_admin.password
    end

    user = User.find_or_initialize_by(account_id: admin.id)
    user.assign_attributes(user_attributes.compact)
    user.save!

    boost_bot_account = Account.find_by(id: @community_admin.account_id)

    CommunityCreationJob.perform_later(@community.id, boost_bot_account.user.id)

    if @community_admin.role == 'UserAdmin'
      @community.create_content_type(channel_type: 'custom_channel', custom_condition: 'OR') unless @community.content_type
    end

    # Set account cleanup policy
    policy = AccountStatusesCleanupPolicy.find_or_initialize_by(account_id: admin.id)
    policy.assign_attributes(enabled: true, min_status_age: 1.week.seconds)
    policy.save!
  rescue StandardError => e
    Rails.logger.error "Error in CommunityAdminPostService: #{e.message}"
  end
end
