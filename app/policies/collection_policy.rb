class CollectionPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_collections)
  end

  def show?
    index?
  end

  def create?
    master_admin? || can?(:manage_collections)
  end

  def update?
    master_admin? || can?(:manage_collections)
  end

  def destroy?
    master_admin? || can?(:manage_collections)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
