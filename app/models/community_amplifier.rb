# == Schema Information
#
# Table name: patchwork_community_amplifiers
#
#  id                     :bigint           not null, primary key
#  amplifier_settings     :jsonb            not null
#  amplifier_turn_on      :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  patchwork_community_id :bigint           not null
#
# Indexes
#
#  index_patchwork_commu_amplifiers_on_account_and_patchwork_commu  (account_id,patchwork_community_id) UNIQUE
#  index_patchwork_community_amplifiers_on_patchwork_community_id   (patchwork_community_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (patchwork_community_id => patchwork_communities.id)
#
class CommunityAmplifier < ApplicationRecord
  self.table_name = 'patchwork_community_amplifiers'
end
