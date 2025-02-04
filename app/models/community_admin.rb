class CommunityAdmin < ApplicationRecord
  self.table_name = 'patchwork_communities_admins'
  belongs_to :community, foreign_key: 'patchwork_community_id'
  belongs_to :account, foreign_key: 'account_id', optional: true

  validates :email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
    uniqueness: { case_sensitive: false, message: "already exists in the system." }

  validates :username, presence: true

  ROLES = %w[OrganisationAdmin UserAdmin].freeze

  validates :role, inclusion: { in: ROLES, message: "%{value} is not a valid role" }, allow_blank: true

  validates :account_id, uniqueness: { scope: :patchwork_community_id, message: "is already an admin for this community" }, allow_blank: true

  def self.ransackable_attributes(auth_object = nil)
    ["account_id", "created_at", "id", "id_value", "patchwork_community_id", "updated_at"]
  end
end
