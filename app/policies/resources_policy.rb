class ResourcesPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_resources)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
