class CustomEmojiPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_custom_emojis)
  end

  def create?
    master_admin? || can?(:manage_custom_emojis)
  end

  def update?
    master_admin? || can?(:manage_custom_emojis)
  end

  def destroy?
    master_admin? || can?(:manage_custom_emojis)
  end

  def batch?
    master_admin? || can?(:manage_custom_emojis)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
