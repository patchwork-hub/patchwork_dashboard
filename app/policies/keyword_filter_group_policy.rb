class KeywordFilterGroupPolicy < ApplicationPolicy
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

  def update_is_active?
    master_admin? || can?(:manage_server_settings)
  end

  def download_csv?
    master_admin? || can?(:manage_server_settings)
  end

  def download_csv_by_server_setting?
    master_admin? || can?(:manage_server_settings)
  end

  class Scope < ApplicationPolicy::Scope
  end
end
