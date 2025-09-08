class AppVersionsController < ApplicationController
  before_action :authorize_master_admin!
  before_action :set_app_version, only: %i[update destroy]
  
  PER_PAGE = 10

  def index
    app_name_key = params[:app_name]&.to_s
    scope = if AppVersion.app_names.value?(app_name_key&.to_i)
      AppVersion.send(AppVersion.app_names.key(app_name_key.to_i)).ransack(params[:q])
    else
      AppVersion.patchwork.ransack(params[:q])
    end
    @app_versions = scope.result.includes(:app_version_histories).order(created_at: :asc).page(params[:page]).per(PER_PAGE)
  end

  def new
    @app_version = AppVersion.new
  end

  def create
    service = CreateAppVersionService.new(app_version_params.merge(os_type: params[:os_type]))

    if service.call
      redirect_to app_versions_url(app_name: service.app_name&.to_i), notice: 'App version was successfully created!'
    else
      flash[:error] = service.errors.full_messages
      redirect_to new_app_version_url(app_name: service.app_name&.to_i || AppVersion.app_names.invert[AppVersion.app_names[:patchwork]])
    end
  end

  def update
    # Update the app version and its history records
    if @app_version.update(app_version_params.except(:released_date))
      # Update the released_date in all associated history records
      if params[:app_version][:released_date].present?
        @app_version.app_version_histories.update_all(released_date: params[:app_version][:released_date])
      end
      redirect_to app_versions_url(app_name: @app_version.app_name_before_type_cast), notice: 'App version was successfully updated.'
    else
      # Set the released_date for form redisplay
      @app_version.released_date = params[:app_version][:released_date]
      render :edit
    end
  end

  def destroy
    app_name = @app_version.app_name_before_type_cast
    @app_version.destroy
    redirect_to app_versions_url(params: {app_name: app_name}), notice: 'App version was successfully destroyed.'
  end

  def deprecate
    @history = AppVersionHistory.find(params[:id])
    @history.update(deprecated: !@history.deprecated)
    render json: {message: 'success'}, status: 200
  end

  def authorize_master_admin!
    authorize :master_admin, :index?
  end

  private

  def set_app_version
    @app_version = AppVersion.find(params[:id])
  end

  def app_version_params
    params.require(:app_version).permit(:version_name, :app_name, :released_date)
  end
end
