# frozen_string_literal: true

# == Schema Information
#
# Table name: patchwork_settings
#
#  id         :bigint           not null, primary key
#  app_name   :integer          default("patchwork"), not null
#  settings   :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_patchwork_settings_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class Setting < ApplicationRecord
  self.table_name = 'patchwork_settings'

  belongs_to :account, class_name: 'Account'

  validates :account, presence: true, uniqueness: { scope: :app_name, case_sensitive: false }
  validates :app_name, presence: true
  validates :settings, presence: true

  enum app_name: { patchwork: 0, newsmast: 1 } , _default: :patchwork

end
