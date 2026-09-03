# == Schema Information
#
# Table name: patchwork_communities_statuses
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  patchwork_community_id :bigint           not null
#  status_id              :bigint           not null
#
# Indexes
#
#  index_patchwork_communities_statuses_on_patchwork_community_id  (patchwork_community_id)
#  index_patchwork_communities_statuses_on_status_and_community    (status_id,patchwork_community_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patchwork_community_id => patchwork_communities.id)
#  fk_rails_...  (status_id => statuses.id)
#
class CommunityStatus < ApplicationRecord
  self.table_name = 'patchwork_communities_statuses'
end
