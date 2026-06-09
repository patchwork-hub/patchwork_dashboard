require "application_responder"

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  helper_method :current_account

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  require 'httparty'

  self.responder = ApplicationResponder
  respond_to :html

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
    if request.format.json?
      render json: { error: "You are not authorized to perform this action." }, status: :forbidden
    else
      flash[:error] = "You are not authorized to perform this action."

      # Find the first accessible local sidebar page to avoid redirect loops
      safe_path = begin
        menu_items = view_context.sidebar_menu_items.flat_map { |group| group[:items] }
        first_local = menu_items.find { |item| item[:path].to_s.start_with?('/') && item[:target] != '_blank' && item[:path] != request.path }
        first_local&.dig(:path)
      rescue => e
        Rails.logger.error "Error resolving safe redirect path: #{e.message}"
        nil
      end

      if safe_path
        redirect_to safe_path
      else
        sign_out(current_user)
        redirect_to new_user_session_path
      end
    end
  end

  def truthy_param?(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end

  def current_account
    @current_account ||= current_user&.account
  end
end
