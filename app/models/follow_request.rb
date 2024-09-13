class FollowRequest < ApplicationRecord
  belongs_to :account
  belongs_to :target_account, class_name: 'Account'
end
