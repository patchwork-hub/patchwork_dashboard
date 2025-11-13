# == Schema Information
#
# Table name: patchwork_community_types
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  slug          :string
#  sorting_index :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class CommunityType < ApplicationRecord
  self.table_name = 'patchwork_community_types'

    has_many :patchwork_communities,
             class_name: 'Community',
             foreign_key: 'patchwork_community_type_id',
             dependent: :destroy
end
