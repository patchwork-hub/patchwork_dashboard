class CommunityPolicy < ApplicationPolicy
  def initialize_form?
    master_admin? || user_has_access_to_community? || user_admin? || newsmast_admin? || can?(:manage_channels, :manage_channel_feeds, :manage_hubs, :manage_newsmast_channels)
  end

  def index?
    user_has_access_to_community?
  end

  def show?
    index?
  end

  def update?
    index?
  end

  def step0?
    master_admin? || organisation_admin? || can?(:manage_channels)
  end

  def step1?
    initialize_form?
  end

  def step1_save?
    initialize_form?
  end

  def step2?
    master_admin? || user_admin? || newsmast_admin? || can?(:manage_channel_feeds, :manage_newsmast_channels)
  end

  def step2_save?
    initialize_form?
  end

  def step2_update_admin?
    initialize_form?
  end

  def step3?
    record&.content_type&.custom_channel?
  end

  def step4?
    step3?
  end

  def step5?
    # !related_user_admin?
    false
  end

  def step5_save?
    step5?
  end

  def step5_update?
    step5?
  end

  def step5_delete?
    step5?
  end

  def step6?
    !related_user_admin?
  end

  def manage_additional_information?
    !related_user_admin?
  end

  def set_visibility?
    index?
  end

  private

  def user_has_access_to_community?
    return false unless user.present? && record.present?

    CommunityAdmin.exists?(patchwork_community_id: record.id, account_id: user.account_id)
  end

  def related_user_admin?
    account_id = record&.community_admins&.first&.account_id
    user = User.find_by(account_id: account_id)
    user&.role&.name.in?(%w[UserAdmin])
  end
end
