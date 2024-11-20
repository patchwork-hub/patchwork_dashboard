# frozen_string_literal: true

class CommunityAdminPostService < BaseService
  include ActionView::Helpers::SanitizeHelper

  def call(account, options = {})
    @options = options
    create_admin!
    process_community_admin!
  end

  private

  def community_admin_attribute
    {
      patchwork_community_id: @options[:community_id].to_i,
      email: @options[:email],
      display_name: @options[:display_name],
      username: @options[:username],
      password: @options[:password]
    }.compact
  end

  def process_community_admin!
    @community_admin = CommunityAdmin.new(community_admin_attribute)
    @community_admin.save
    @community_admin
  end

  def create_admin!
    community = Community.find_by_id(@options[:community_id].to_i)
    return unless community
    avatar_file = community&.avatar_image || ''
    header_file = community&.banner_image || ''

    account_name = community.slug.underscore
    domain = ENV['LOCAL_DOMAIN'] || Rails.configuration.x.local_domain
    domain = domain.gsub(/^[^.]+\./, '')
    username = "#{account_name}_channel"
    admin = Account.where(username: username).first_or_initialize(
      username: username,
      display_name: username,
      avatar: avatar_file,
      header: header_file,
      note: strip_tags(community.description)
    )

    admin.save(validate: false)

    account_email = "#{account_name}@#{domain}"
    password = "#{account_name}-Channel@uomu82sl18s82"

    user = User.where(email: account_email).first_or_initialize(
      email: account_email,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.now.utc,
      role: UserRole.find_by(name: 'community-admin'),
      account: admin,
      agreement: true,
      approved: true
    )

    user.save!

    policy = AccountStatusesCleanupPolicy.find_or_initialize_by(account_id: admin.id)

    policy.assign_attributes(
      enabled: true,
      min_status_age: 1.week.seconds
    )

    if policy.save
      puts "Policy created or updated successfully!"
    else
      puts "Failed to create or update policy: #{policy.errors.full_messages.join(", ")}"
    end
  end
end
