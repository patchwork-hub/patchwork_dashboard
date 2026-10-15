# frozen_string_literal: true

# == Schema Information
#
# Table name: custom_emoji_categories
#
#  id                :bigint           not null, primary key
#  name              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  featured_emoji_id :bigint
#
# Indexes
#
#  index_custom_emoji_categories_on_name  (name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (featured_emoji_id => custom_emojis.id) ON DELETE => nullify
#

class CustomEmojiCategory < ApplicationRecord
  has_many :emojis, class_name: 'CustomEmoji', foreign_key: 'category_id', inverse_of: :category, dependent: nil

  validates :name, presence: true, uniqueness: true

  scope :alphabetic, -> { order(name: :asc) }
end
