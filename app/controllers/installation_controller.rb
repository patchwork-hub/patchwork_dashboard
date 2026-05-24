class InstallationController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize :installation, :index?
  end
end
