# == Schema Information
#
# Table name: tags
#
#  id                  :bigint           not null, primary key
#  display_name        :string
#  is_banned           :boolean          default(FALSE)
#  last_status_at      :datetime
#  listable            :boolean
#  max_score           :float
#  max_score_at        :datetime
#  name                :string           default(""), not null
#  requested_review_at :datetime
#  reviewed_at         :datetime
#  trendable           :boolean
#  usable              :boolean
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_tags_on_name_lower_btree  (lower((name)::text) text_pattern_ops) UNIQUE
#
class Tag < ApplicationRecord

end
