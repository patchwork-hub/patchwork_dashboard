require "application_responder"

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  helper_method :current_account

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  require 'httparty'

  self.responder = ApplicationResponder
  respond_to :html

  before_action :authenticate_user_from_cookie
	before_action :authenticate_user!
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

	before_action :prepare_datatable_params, only: %i[ index invitation_codes show ]

	protected

  def prepare_datatable_params
    if request.format.json?
      @q    = params[:search][:value] if params[:search]

      @per  = params[:length].to_i if params[:length]
      @page = (params[:start].to_i / @per) + 1 if params[:start]

      columns = params[:columns] if params[:columns]
      order   = params[:order]['0'] if params[:order]

      @sort   = columns[order[:column]][:data] if columns
      @dir    = order[:dir] if order
    end
  end

  def not_allowed(exception)
    Rails.logger.warn "⚠️ not_allowed"
    respond_to do |format|
      format.html { render :file => "#{Rails.root}/public/403.html", :status => :forbidden, :layout => false }
      format.js { head :forbidden }
      format.json { head :forbidden }
    end
  end

  def not_found(exception)
    Rails.logger.warn "⚠️ not_found"
    respond_to do |format|
      format.html { render file: "#{Rails.root}/public/404.html", :status => 404, :layout => false }
      format.js { head :not_found }
      format.json { head :not_found }
    end
  end


  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."

    if current_user.organisation_admin?
      redirect_back_or_to(communities_path(channel_type: 'channel'))
    elsif current_user.user_admin?
      redirect_back_or_to(communities_path(channel_type: 'channel_feed'))
    else
      redirect_back_or_to(root_path)
    end
  end

  def current_account
    return @current_account if defined?(@current_account)

    @current_account = current_user&.account
  end

  private

  def authenticate_user_from_cookie
    token = cookies[:access_token]
    return unless token

    user_info = validate_token(token)

    if user_info
      user = User.find_by(id: user_info["resource_owner_id"])
      if user
        sign_in(user)
      else
        redirect_to new_user_session_path, alert: 'User not found.'
      end
    else
      redirect_to new_user_session_path, alert: 'Invalid token.'
    end
  end

  def validate_token(token)
    begin
      env = ENV.fetch('RAILS_ENV', nil)
      url = case env
        when 'staging'
          'https://staging.patchwork.online/oauth/token/info'
        when 'production'
          'https://channel.org/oauth/token/info'
        else
          'http://localhost:3000/oauth/token/info'
        end
      response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{token}" })
      JSON.parse(response.body)
    rescue HTTParty::Error => e
      Rails.logger.error "Error fetching user info: #{e.message}"
      nil
    end
  end
end
