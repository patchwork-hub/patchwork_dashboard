# == Schema Information
#
# Table name: patchwork_community_types
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  slug          :string           not null
#  sorting_index :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_patchwork_community_types_on_slug  (slug) UNIQUE
#
class CommunityType < ApplicationRecord
  self.table_name = 'patchwork_community_types'

    has_many :patchwork_communities,
             class_name: 'Community',
             foreign_key: 'patchwork_community_type_id',
             dependent: :destroy
end
