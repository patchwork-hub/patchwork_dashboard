class AutoFollowAccount < ApplicationRecord
  self.table_name = 'patchwork_auto_follow_accounts'

  belongs_to :auto_follow, foreign_key: :patchwork_auto_follow_id, touch: true
  belongs_to :account

  validates :account_id, uniqueness: { scope: :patchwork_auto_follow_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end