require "application_responder"

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  helper_method :current_account

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  require 'httparty'

  self.responder = ApplicationResponder
  respond_to :html

	# before_action :authenticate_user!
  before_action :handle_authentication
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

    # Handles authentication based on cookies
    def handle_authentication_cookies
      if user_signed_in? && !cookies[:access_token].present?
        clear_invalid_token
      end
    end

  # Handles authentication based on cookies or Devise
  def handle_authentication

    if cookies[:access_token].present?
      authenticate_user_from_cookie || clear_invalid_token
    else
      authenticate_user!
    end
  end

  def authenticate_user_from_cookie
    token = cookies[:access_token]
    return unless token

    user_info = validate_token(token)

    if user_info
      user = User.find_by(id: user_info["resource_owner_id"])
      byebug
      if user && (user.master_admin? || user.organisation_admin? || user.user_admin?)
        byebug
        sign_in(user) unless user_signed_in?
        if user.organisation_admin?
          byebug

          redirect_to communities_path(channel_type: 'channel')
        elsif user.user_admin?
          byebug

          redirect_to communities_path(channel_type: 'channel_feed')
        else
          byebug

          redirect_to root_path
        end
      else
        authenticate_user!
      end
    else
      clear_invalid_token
    end
  end

  # Clear cookies and redirect to login if token is invalid
  def clear_invalid_token
    cookies.delete(:access_token, domain: Rails.env.production? ? '.channel.org' : :all)
    sign_out(current_user) if user_signed_in?
    redirect_to new_user_session_path, alert: 'Session expired. Please log in again.'
  end

  def validate_token(token)
    return if token.blank?
  
    begin
      url = Rails.env.development? ? 'http://localhost:3000/oauth/token/info' : 'https://channel.org/oauth/token/info'
      response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{token}" })
  
      if response.success?
        JSON.parse(response.body) # Returns the token payload
      else
        Rails.logger.warn "Token validation failed with status #{response.code}: #{response.body}"
        nil
      end
    rescue HTTParty::Error => e
      Rails.logger.error "Error validating token: #{e.message}"
      nil
    end
  end
end
