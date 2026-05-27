class KeywordFilterPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_server_settings)
  end

  def show?
    index?
  end

  def create?
    master_admin? || can?(:manage_server_settings)
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def update?
    master_admin? || can?(:manage_server_settings)
  end

  def destroy?
    master_admin? || can?(:manage_server_settings)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
