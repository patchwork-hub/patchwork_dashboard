class ContentType < ApplicationRecord
  self.table_name = 'patchwork_content_types'
  belongs_to :community, class_name: 'Community', foreign_key: 'patchwork_community_id'

  enum channel_type: {
    broadcast_channel: 'Broadcast Channel',
    group_channel: 'Group Channel',
    custom_channel: 'Custom Channel'
  }

  enum contributor_condition: {
    or_condition: 'OR',
    and_condition: 'AND'
  }

  validates :channel_type, presence: true, inclusion: { in: channel_types.keys }
  validates :contributor_condition, inclusion: { in: contributor_conditions.keys, allow_nil: true }
end
