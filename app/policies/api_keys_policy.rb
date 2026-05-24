class ApiKeysPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_api_keys)
  end

  def show?
    index?
  end

  def create?
    master_admin? || can?(:manage_api_keys)
  end

  def update?
    master_admin? || can?(:manage_api_keys)
  end

  def destroy?
    master_admin? || can?(:manage_api_keys)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
