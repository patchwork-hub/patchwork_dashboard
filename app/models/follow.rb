# == Schema Information
#
# Table name: follows
#
#  id                :bigint           not null, primary key
#  languages         :string           is an Array
#  notify            :boolean          default(FALSE), not null
#  show_reblogs      :boolean          default(TRUE), not null
#  uri               :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  target_account_id :bigint           not null
#
# Indexes
#
#  index_follows_on_account_id_and_target_account_id  (account_id,target_account_id) UNIQUE
#  index_follows_on_target_account_id_and_account_id  (target_account_id,account_id)
#
# Foreign Keys
#
#  fk_32ed1b5560  (account_id => accounts.id) ON DELETE => cascade
#  fk_745ca29eac  (target_account_id => accounts.id) ON DELETE => cascade
#
class Follow < ApplicationRecord
  belongs_to :account
  belongs_to :target_account, class_name: 'Account'

  def self.ransackable_attributes(auth_object = nil)                                                            
    ["account_id",  "target_account_id"]                                                                                             
  end

  def self.ransackable_associations(auth_object = nil)                                                          
    ["account", "target_account"]                                                                               
  end
end
