class MasterAdminsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_master_admin!
  before_action :set_master_admin, only: [:edit, :update]

  def index
    @master_admins = User.joins(:account)
                          .where(role_id: UserRole.assignable.select(:id))
                          .where.not(account_id: CommunityAdmin.where.not(account_id: nil).select(:account_id))
                          .select(
                            'users.id AS user_id,
                             accounts.username,
                             accounts.display_name,
                             users.email,
                             users.role_id'
                          )
  end

  def new
    @master_admin = Form::MasterAdmin.new(current_user: current_user)
  end

  def create
    @master_admin = Form::MasterAdmin.new(master_admin_params.merge(current_user: current_user))

    if @master_admin.save
      redirect_to master_admins_path, notice: 'Master admin created successfully.'
    else
      flash.now[:error] = @master_admin.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @master_admin.update(master_admin_params)
      redirect_to master_admins_path, notice: 'Master admin updated successfully.'
    else
      flash.now[:error] = @master_admin.errors.full_messages.join(', ')
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def master_admin_role
    UserRole.find_by!(name: 'MasterAdmin')
  end

  def set_master_admin
    user = User.find(params[:id])
    @master_admin = Form::MasterAdmin.new(
      id: user.id,
      display_name: user.account&.display_name,
      username: user.account&.username,
      email: user.email,
      note: user.account&.note,
      role: user.role&.id,
      current_user: current_user
    )
  end

  def master_admin_params
    params.require(:form_master_admin)
          .permit(:id, :display_name, :username, :role, :email, :password, :password_confirmation, :note)
  end

  def authorize_master_admin!
    authorize :master_admin, "#{action_name}?"
  end
end
