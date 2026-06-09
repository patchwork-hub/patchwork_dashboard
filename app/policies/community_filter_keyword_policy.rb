class CommunityFilterKeywordPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_global_filters)
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
