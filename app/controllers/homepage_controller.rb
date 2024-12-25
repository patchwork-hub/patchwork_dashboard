class HomepageController < ApplicationController
  before_action :handle_authentication_cookies
  before_action :authorize_master_admin!

  def index
  end

  private

  def authorize_master_admin!
    authorize :master_admin, :index?
  end
end
