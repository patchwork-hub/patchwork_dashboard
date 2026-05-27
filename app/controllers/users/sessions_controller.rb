# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  require 'httparty'

  skip_before_action :verify_authenticity_token, only: [:destroy]

  def new
    super
  end

  def create
    self.resource = warden.authenticate!(auth_options)

    unless policy(resource).login?
      handle_unauthorized_login
      return
    end

    unless resource.master_admin? || resource.can?(:view_newsmast_dashboard)
      community_admin = find_active_community_admin(resource)

      if community_admin.nil?
        handle_unauthorized_login
        return
      end
    end

    super do |resource|
      if resource.persisted?
        sign_in(resource)
      end
    end
  end

  def destroy
    # Revoke the access token from Mastodon
    revoke_access_token(cookies[:access_token])

    # Clear the access token cookie
    cookies.delete(:access_token, domain: Rails.env.development? ? :all : '.channel.org')
    puts params[:authenticity_token]
    super
  end

  protected

  def after_sign_in_path_for(resource)
    begin
      menu_items = view_context.sidebar_menu_items.flat_map { |group| group[:items] }
      first_local_item = menu_items.find { |item| item[:path].to_s.start_with?('/') && item[:target] != '_blank' }
      if first_local_item
        first_local_item[:path]
      else
        root_path
      end
    rescue => e
      Rails.logger.error "Error resolving dynamic post-login path: #{e.message}"
      if resource.master_admin?
        root_path
      elsif resource.can?(:view_newsmast_dashboard)
        communities_path(channel_type: 'newsmast')
      elsif resource.dashboard_admin?
        communities_path(channel_type: 'channel')
      elsif resource.organisation_admin?
        communities_path(channel_type: 'channel')
      elsif resource.user_admin?
        communities_path(channel_type: 'channel_feed')
      elsif resource.hub_admin?
        communities_path(channel_type: 'hub')
      else
        communities_path(channel_type: 'newsmast')
      end
    end
  end

  private

  def revoke_access_token(token)
    return unless token

    begin
      url = Rails.env.development? ? 'http://localhost:3000/oauth/revoke' : 'https://channel.org/oauth/revoke'

      HTTParty.post(
        url,
        body: {
          token: token,
          client_id: "7Xn_TbJq9D5uWhT_sL9Te9yXAJ26UrxSlXtBoKT7rt0",
          client_secret: "5yf68rGhPsxPuSQd2RMHZ8tHV02GPIYOV5fT88V07o8"
        },
        headers: { 'Authorization': "Bearer #{token}" }
      )
    rescue HTTParty::Error => e
      Rails.logger.error "Failed to revoke access token: #{e.message}"
    end
  end

  def find_active_community_admin(user)
    if user.organisation_admin?
      CommunityAdmin.find_by(
        account_id: user.account_id,
        account_status: CommunityAdmin.account_statuses[:active]
      )
    else
      CommunityAdmin.find_by(
        account_id: user.account_id,
        is_boost_bot: true,
        account_status: CommunityAdmin.account_statuses[:active]
      )
    end
  end

  def handle_unauthorized_login
    sign_out(resource)
    flash[:error] = "You are not authorized to log in."
    redirect_to new_user_session_path
  end
end
