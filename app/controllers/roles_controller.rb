class RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [:edit, :update, :destroy]

  def index
    authorize :user_role, :index?
    @roles = UserRole.where.not(id: UserRole::EVERYONE_ROLE_ID)
                     .left_joins(:users)
                     .select('user_roles.*, COUNT(users.id) AS users_count')
                     .group('user_roles.id')
                     .order(position: :desc)
  end

  def new
    authorize :user_role, :create?
    @role = UserRole.new
  end

  def create
    authorize :user_role, :create?

    @role = UserRole.new(role_params)
    @role.current_account = current_user

    if @role.save
      redirect_to roles_path, notice: 'Role created successfully.'
    else
      flash.now[:error] = @role.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @role, :update?
  end

  def update
    authorize @role, :update?

    @role.current_account = current_user

    if @role.update(role_params)
      redirect_to roles_path, notice: 'Role updated successfully.'
    else
      flash.now[:error] = @role.errors.full_messages.join(', ')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @role, :destroy?
    @role.destroy!
    redirect_to roles_path, notice: 'Role deleted successfully.'
  end

  private

  def set_role
    @role = UserRole.find(params[:id])
  end

  def role_params
    params.require(:user_role).permit(:name, :color, :highlighted, :position, permissions_as_keys: [])
  end
end
