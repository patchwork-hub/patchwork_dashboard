class CommunityAdmin < ApplicationRecord
  self.table_name = 'patchwork_communities_admins'
  belongs_to :community, foreign_key: 'patchwork_community_id'

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  validates :username, presence: true

  ROLES = %w[OrganisationAdmin UserAdmin].freeze

  validates :role, presence: true, inclusion: { in: ROLES }

  def self.ransackable_attributes(auth_object = nil)
    ["account_id", "created_at", "id", "id_value", "patchwork_community_id", "updated_at"]
  end
end
