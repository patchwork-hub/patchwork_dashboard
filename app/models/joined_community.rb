# == Schema Information
#
# Table name: patchwork_joined_communities
#
#  id                     :bigint           not null, primary key
#  is_primary             :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  patchwork_community_id :bigint           not null
#
# Indexes
#
#  index_patchwork_joined_communities_on_account_id              (account_id)
#  index_patchwork_joined_communities_on_patchwork_community_id  (patchwork_community_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (patchwork_community_id => patchwork_communities.id) ON DELETE => cascade
#
class JoinedCommunity < ApplicationRecord
  self.table_name = 'patchwork_joined_communities'

  belongs_to :community, foreign_key: 'patchwork_community_id'
  belongs_to :account, foreign_key: 'account_id'

  validates :community, presence: true
  validates :account, presence: true, uniqueness: { scope: :patchwork_community_id }

  validate :ensure_only_one_primary_for_account

  private
  def ensure_only_one_primary_for_account
    if is_primary? && account.joined_communities.where(is_primary: true).where.not(id: id).exists?
      errors.add(:is_primary, I18n.t('activerecord.errors.models.joined_community.attributes.is_primary.only_one_primary'))
    end
  end
end
