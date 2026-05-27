class AccountPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:view_accounts)
  end

  def show?
    index?
  end

  def follow?
    index?
  end

  def unfollow?
    index?
  end

  def export?
    index?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
