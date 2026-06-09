class UserRolePolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_roles)
  end

  def create?
    master_admin? || can?(:manage_roles)
  end

  def update?
    (master_admin? || can?(:manage_roles)) && (user_role_overrides_record? || self_editing?)
  end

  def destroy?
    (master_admin? || can?(:manage_roles)) && !record.everyone? && user_role_overrides_record? && !self_editing?
  end

  private

  def user_role_overrides_record?
    user&.role&.overrides?(record)
  end

  def self_editing?
    user&.role&.id == record.id
  end

  class Scope < ApplicationPolicy::Scope
  end
end
