class UserPolicy < ApplicationPolicy
  def login?
    master_admin? || can?(:view_newsmast_dashboard)
  end

  def master_admin?
    user&.role&.name.in?(%w[MasterAdmin])
  end

  def dashboard_admin?
    user&.role&.name.in?(%w[DashboardAdmin])
  end

  def organisation_admin?
    user&.role&.name.in?(%w[OrganisationAdmin])
  end

  def user_admin?
    user&.role&.name.in?(%w[UserAdmin])
  end

  def hub_admin?
    user&.role&.name.in?(%w[HubAdmin])
  end

  def newsmast_admin?
    user&.role&.name.in?(%w[NewsmastAdmin])
  end

  def user_is_not_community_admin?
    (organisation_admin? || user_admin? || hub_admin? || newsmast_admin?) && !CommunityAdmin.exists?(account_id: user.account_id)
  end

  def change_role?
    role.can?(:manage_roles) && role.overrides?(record.role)
  end
end
