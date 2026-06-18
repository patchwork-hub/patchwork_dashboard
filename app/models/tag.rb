# == Schema Information
#
# Table name: tags
#
#  id                  :bigint           not null, primary key
#  display_name        :string
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
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def self.find_or_create_case_insensitive!(name:, display_name: nil)
    normalized_name = name.to_s.strip
    raise ActiveRecord::RecordInvalid, new(name: normalized_name) if normalized_name.blank?

    existing_tag = where('LOWER(name) = ?', normalized_name.downcase).first
    return existing_tag if existing_tag

    create!(name: normalized_name, display_name: display_name || normalized_name)
  rescue ActiveRecord::RecordNotUnique
    where('LOWER(name) = ?', normalized_name.downcase).first!
  end

end
