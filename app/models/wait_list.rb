# frozen_string_literal: true

# == Schema Information
#
# Table name: patchwork_wait_lists
#
#  id              :bigint           not null, primary key
#  channel_type    :integer          default("channel"), not null
#  confirmed_at    :datetime
#  description     :text
#  email           :text
#  invitation_code :text             not null
#  used            :boolean          default(FALSE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint
#
# Indexes
#
#  index_patchwork_wait_lists_on_account_id       (account_id)
#  index_patchwork_wait_lists_on_invitation_code  (invitation_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class WaitList < ApplicationRecord
  self.table_name = 'patchwork_wait_lists'
  belongs_to :account, class_name: 'Account', optional: true

  enum channel_type: { channel: 0, hub: 1 }
  
  validates :account_id, uniqueness: true, allow_nil: true
  validates :invitation_code, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: :invalid }, allow_blank: true
  validates :description, length: { maximum: 255 }, allow_blank: true
  validates :channel_type, presence: true, inclusion: { in: channel_types.keys }

  def generate_invitation_code
    loop do
      self.invitation_code = SecureRandom.random_number(100_000..999_999).to_s
      break unless WaitList.exists?(invitation_code: self.invitation_code)
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    ["invitation_code", "email"]
  end
end
