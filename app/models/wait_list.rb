# frozen_string_literal: true

class WaitList < ApplicationRecord
  self.table_name = 'patchwork_wait_lists'
  belongs_to :account, class_name: 'Account', optional: true

  validates :account_id, uniqueness: true, allow_nil: true
  validates :invitation_code, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :description, length: { maximum: 255 }, allow_blank: true

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
