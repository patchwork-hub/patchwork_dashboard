# == Schema Information
#
# Table name: patchwork_starter_pack_accounts
#
#  id                        :bigint           not null, primary key
#  position                  :integer          default(0), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  patchwork_starter_pack_id :bigint           not null
#
# Indexes
#
#  index_patchwork_starter_pack_accounts_on_account_id  (account_id)
#  index_starter_pack_accounts_unique                   (patchwork_starter_pack_id,account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (patchwork_starter_pack_id => patchwork_starter_packs.id) ON DELETE => cascade
#
class StarterPackAccount < ApplicationRecord
  self.table_name = 'patchwork_starter_pack_accounts'

  belongs_to :starter_pack, foreign_key: :patchwork_starter_pack_id, touch: true
  belongs_to :account
  validates :account_id, uniqueness: { scope: :patchwork_starter_pack_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
