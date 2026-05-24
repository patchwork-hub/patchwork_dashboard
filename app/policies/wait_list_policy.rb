class WaitListPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_invitation_codes)
  end

  def show?
    index?
  end

  def create?
    master_admin? || can?(:manage_invitation_codes)
  end

  def update?
    master_admin? || can?(:manage_invitation_codes)
  end

  def destroy?
    master_admin? || can?(:manage_invitation_codes)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
