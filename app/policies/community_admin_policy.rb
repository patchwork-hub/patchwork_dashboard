class CommunityAdminPolicy < ApplicationPolicy

  def create?
    master_admin? || can?(:manage_community_admins)
  end

  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    # def resolve
    #   scope.all
    # end
  end
end
