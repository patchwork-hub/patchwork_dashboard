class MasterAdminPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_master_admins)
  end

  def create?
    master_admin? || can?(:manage_master_admins)
  end

  def update?
    master_admin? || can?(:manage_master_admins)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
