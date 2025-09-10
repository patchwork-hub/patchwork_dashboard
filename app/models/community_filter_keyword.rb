# == Schema Information
#
# Table name: patchwork_communities_filter_keywords
#
#  id                     :bigint           not null, primary key
#  filter_type            :string           default("filter_out"), not null
#  is_filter_hashtag      :boolean          default(FALSE), not null
#  keyword                :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  patchwork_community_id :bigint
#
# Indexes
#
#  idx_on_patchwork_community_id_eadde3c87b                       (patchwork_community_id)
#  index_on_keyword_is_filter_hashtag_and_patchwork_community_id  (keyword,is_filter_hashtag,patchwork_community_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patchwork_community_id => patchwork_communities.id) ON DELETE => cascade
#
class CommunityFilterKeyword < ApplicationRecord
  self.table_name = 'patchwork_communities_filter_keywords'

  belongs_to :community, class_name: 'Community', foreign_key: 'patchwork_community_id', optional: true

  validates :keyword, presence: true
  FILTER_TYPES = %w[filter_in filter_out].freeze
  validates :filter_type, presence: true, inclusion: { in: FILTER_TYPES }
  validates_uniqueness_of :keyword, scope: [:is_filter_hashtag, :patchwork_community_id], message: "already exists."

  def self.ransackable_attributes(auth_object = nil)
    ["keyword"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
