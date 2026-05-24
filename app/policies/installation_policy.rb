class InstallationPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_installation)
  end

  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    # def resolve
    #   scope.all
    # end
  end
end
