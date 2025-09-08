# == Schema Information
#
# Table name: patchwork_communities_hashtags
#
#  id                     :bigint           not null, primary key
#  hashtag                :string
#  name                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  patchwork_community_id :bigint           not null
#
# Indexes
#
#  index_patchwork_communities_hashtags_on_hashtag_and_community   (patchwork_community_id,hashtag) UNIQUE
#  index_patchwork_communities_hashtags_on_patchwork_community_id  (patchwork_community_id)
#
# Foreign Keys
#
#  fk_rails_...  (patchwork_community_id => patchwork_communities.id) ON DELETE => cascade
#
class CommunityHashtag < ApplicationRecord
  self.table_name = 'patchwork_communities_hashtags'

  belongs_to :community, class_name: 'Community', foreign_key: 'patchwork_community_id', optional: true

  validates :hashtag, presence: true, uniqueness: { scope: :patchwork_community_id }
  validates :community, presence: true

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "hashtag", "id", "id_value", "name", "patchwork_community_id", "updated_at"]
  end
end
