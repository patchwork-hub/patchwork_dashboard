require 'spreadsheet'

class Account < ApplicationRecord
  has_one :user, inverse_of: :account
  has_many :communities
  has_many :community_admins

  validates :username, uniqueness: true, presence: true

  def self.ransackable_attributes(auth_object = nil)
    ["dob", "domain", "uri", "url", "username"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["community_admins"]
  end

  def followed?(target_account_id)
    Follow.exists?(account_id: id, target_account_id: target_account_id)
  end

  def self.filter_unfollowed_users(account_id)
    Account.left_joins(:follows)
           .where.not(follows: { account_id: account_id })
           .distinct
  end
  
end


