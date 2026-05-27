class ResourcesController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize :resources, :index?
  end
end
