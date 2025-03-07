class CommunityFilterKeyword < ApplicationRecord
  self.table_name = 'patchwork_communities_filter_keywords'

  belongs_to :community, class_name: 'Community', foreign_key: 'patchwork_community_id'

  validates :keyword, presence: true
  FILTER_TYPES = %w[filter_in filter_out].freeze
  validates :filter_type, presence: true, inclusion: { in: FILTER_TYPES }
  validates_uniqueness_of :keyword, scope: [:is_filter_hashtag, :patchwork_community_id], message: "already exists."
end
