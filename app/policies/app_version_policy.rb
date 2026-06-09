class AppVersionPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_app_versions)
  end

  def create?
    master_admin? || can?(:manage_app_versions)
  end

  def update?
    master_admin? || can?(:manage_app_versions)
  end

  def destroy?
    master_admin? || can?(:manage_app_versions)
  end

  def deprecate?
    master_admin? || can?(:manage_app_versions)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
