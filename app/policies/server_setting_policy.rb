class ServerSettingPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_server_settings)
  end

  def show?
    index?
  end

  def create?
    master_admin? || can?(:manage_server_settings)
  end

  def update?
    master_admin? || can?(:manage_server_settings)
  end

  def group_data?
    index?
  end

  def branding?
    update?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
